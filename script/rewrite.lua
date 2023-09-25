local lock = require("resty.lock")
local http = require("http")
local json = require("cjson")
local init = require("init")
local lfs = require("lfs")

local sharedttl = init.sharedttl
local domainurl = init.socketapi .. "/socket/domain?host="
local cachedir = init.cachedir


---@return string?
local socketClient = function(_, host)
    local my_lock, newlockerr = lock:new("domain_lock")
    if not my_lock then
        ngx.log(ngx.ERR, "cant create domain_lock:", newlockerr)
        return
    end
    local elapsed, elapsederr = my_lock:lock(host)
    if not elapsed then
        ngx.log(ngx.ERR, "cant lock domain_lock:", elapsederr)
        return
    end
    -- 锁的等待者执行。
    local value, _ = ngx.shared.domain:get(host)
    if value then
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock domain_lock:", err)
        end
        return tostring(value)
    end
    -- 强制限制避免回源失败的缓存穿透
    local sharedsuccess, sharederr, sharedforcible = ngx.shared.domain:add(host .. ".lock", true, sharedttl)
    if sharederr and sharederr ~= "exists" then
        ngx.log(ngx.ERR, "ngx.shared.domain err:", sharederr)
    end
    if sharedforcible then
        ngx.log(ngx.ERR, "ngx.shared.domain no memory")
    end
    if not sharedsuccess then
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock domain_lock:", err)
        end
        return nil
    end
    -- 再次后台获取
    local httpc = http.new()
    if not httpc then
        ngx.log(ngx.ERR, "http.new return nil")
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock domain_lock:", err)
        end
        return
    end
    local res, reqerr = httpc:request_uri(domainurl .. host)
    if not res then
        ngx.log(ngx.ERR, "request_uri err:", reqerr)
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock domain_lock:", err)
        end
        return
    end
    if res.status == 200 then
        local success, seterr, forcible = ngx.shared.domain:set(host, res.body, sharedttl)
        if seterr or not success then
            ngx.log(ngx.ERR, "ngx.shared.domain set err:", seterr)
        end
        if forcible then
            ngx.log(ngx.ERR, "ngx.shared.domain_lock no memory")
        end
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock domain_lock:", err)
        end
        return res.body
    else
        ngx.log(ngx.ERR, "status:", res.status, "|body:", res.body)
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock domain_lock:", err)
        end
        return
    end
end

---从socket api获取域名配置
---@param host string
---@return table? {backend:table,cache:table}
local function getSocketDomain(host)
    local value, flags, stale = ngx.shared.domain:get_stale(host)
    if value then -- 存在则直接返回。
        if stale then
            local ok, err = ngx.timer.at(0, socketClient, host)
            if not ok then
                ngx.log(ngx.ERR, "cont create ngx.timer err:", err)
            end
        end
        return json.decode(tostring(value))
    else
        local valuestr = socketClient(0, host)
        if not valuestr then
            return
        end
        return json.decode(valuestr)
    end
end

-- 生成多级缓存路径
---@param uri string 请求路径
---@return string format 是否有效
local function cachepath(uri)
    local md5 = ngx.md5(uri)
    local dir1, dir2 = md5:sub(1, 2), md5:sub(3, 4)
    return string.format("/%s/%s/%s", dir1, dir2, md5)
end


-- 验证缓存是否过期
---@param path string 文件路径
---@param expired number 缓存时间
---@return boolean val 是否有效
local function cachevalid(path, expired)
    local modification, err = lfs.attributes(path, "modification")
    if modification then
        local expired_time = expired * 60 + modification
        if expired_time > os.time() then
            return true
        end
    end
    return false
end

-- 验证是否进行缓存行为 + 锁
---@param path string 文件路径
---@param limit number 触发下载的要求
---@return boolean ok 是否执行缓存
local function cachelock(path, limit)
    local value, err, forcible = ngx.shared.cache_lock:incr(path, 1, 0, sharedttl)
    if forcible then
        ngx.log(ngx.ERR, "ngx.shared.cache_lock no memory")
    end
    if not value then
        ngx.log(ngx.ERR, err)
        return false
    end
    if value == limit then
        return true
    end
    return false
end

local function setup()
    local domain = ngx.var.host
    local config = getSocketDomain(domain)
    if config == nil then -- 没有获取到域名配置
        init.setNotFoundDomain()
        return
    end
    -- 回源请求。
    if ngx.var.request_method == "GET" then
        local doCacheTime = 0 --缓存过期时间
        if config.cache ~= nil then
            for _, cache in ipairs(config.cache) do
                if cache.path and ngx.var.uri:match(cache.path) then
                    doCacheTime = cache.time
                    break
                end
            end
        end
        if doCacheTime > 0 then --命中缓存规则
            local filepath = config.identity .. cachepath(ngx.var.uri)
            local doCacheFilePath = cachedir .. "/" .. filepath
            if cachevalid(doCacheFilePath, doCacheTime) then --缓存命中
                ngx.req.set_uri_args({
                    cache_file = doCacheFilePath,
                    resp_header = json.encode(config.backend.resp_header)
                })
                ngx.req.set_uri("/@cache", true)
                return
            end
            if cachelock(doCacheFilePath, config.docachelimit) then -- 给缓存行为加锁
                ngx.ctx.docache = true
                ngx.ctx.docachefilepath = doCacheFilePath
                ngx.ctx.docachetime = doCacheTime
                ngx.ctx.docacheidentity = config.identity
            end
        end
    end
    ngx.ctx.backend = config.backend
end

return {
    setup = setup
}
