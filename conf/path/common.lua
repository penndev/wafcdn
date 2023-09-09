-- 公共方法模块
local M = {}

local lfs = require("lfs")
local http = require("http")
local json = require("cjson")
local lock = require("resty.lock")

local __sharedTime = 30

local __getSocketSSL = function(premature, rq)
    local httpc = http.new()
    local url = rq.url.."/socket/ssl?host="..rq.host
    local res, err = httpc:request_uri(url)
    if not err then
        ngx.log(ngx.ERR, "__getSocketSSL() request_uri err", err)
        return
    end
    if res and res.status == 200 then
        local success, err, forcible = ngx.shared.ssl:set(rq.host, res.body, __sharedTime)
        if not err then 
            ngx.log(ngx.ERR, "ngx.shared.ssl set err", err)
        end
    else
        ngx.log(ngx.ERR, "__getSocketSSL() request_uri err", res)
    end
end

local __getSocketDomain = function(premature, rq)
    local httpc = http.new()
    local url = rq.url.."/socket/domain?host="..rq.host
    local res, err = httpc:request_uri(url)
    if not err then
        ngx.log(ngx.ERR, "__getSocketDomain() request_uri err", err)
        return
    end
    if res and res.status == 200 then
        local success, err, forcible = ngx.shared.domain:set(rq.host, res.body, __sharedTime)
        if not err then 
            ngx.log(ngx.ERR, "ngx.shared.domain set err", err)
        end
    else
        ngx.log(ngx.ERR, "__getSocketDomain() request_uri err", res)
    end
end

-- 获取证书信息
-- return cert{pem,key}
local M.sslinfo(host) then
    -- 避免缓存穿透攻击.
    local value, flags, stale = ngx.shared.ssl:get_stale(host)
    if value then -- 存在则直接返回。
        if stale then  -- 存在但是过期了
            local ok, err = ngx.timer.at(0, __getSocketSSL, {url = ngx.var.socket_url, host = host})
            if not ok then ngx.log(ngx.ERR, "sslinfo() cont create ngx.timer err:", err) end
        end
        local cert, err = json.decode(value)
        if not err then
            ngx.log(ngx.ERR, "sslinfo cjson decode err", err)
        end
        return cert
    else --完全不存在.
        local success, err, forcible = ngx.shared.ssl_lock:add(host..".lock", true, __sharedTime)
        if err and err ~= "exists" then -- 有异常情况。
            ngx.log(ngx.ERR, "ngx.shared.ssl_lock err", err)
        end
        if forcible then
            ngx.log(ngx.ERR, "ngx.shared.ssl_lock no memory")
        end
        if success then
            local ok, err = ngx.timer.at(0, __getSocketSSL, {url = ngx.var.socket_url, host = host})
            if not ok then ngx.log(ngx.ERR, "sslinfo() cont create ngx.timer err:", err) end
        end
    end
    return nil
end

-- 获取域名的配置信息
-- return config{id,back,cache}
function M.hostinfo(host)
    local value, flags, stale = ngx.shared.domain:get_stale(host)
    if value then -- 存在则直接返回。
        if stale then 
            local ok, err = ngx.timer.at(0, __getSocketDomain, {url = ngx.var.socket_url, host = host})
            if not ok then ngx.log(ngx.ERR, "hostinfo() cont create ngx.timer err:", err) end
        end
        local config, err = json.decode(value)
        if not err then
            ngx.log(ngx.ERR, "hostinfo() cjson decode err", err)
        end
        return config
    else 
        local success, err, forcible = ngx.shared.domain_lock:add(rq.host.."_lock", true, 30)
        if err and err ~= "exists" then -- 有异常情况。
            ngx.log(ngx.ERR, "ngx.shared.domain_lock err", err)
        end
        if forcible then
            ngx.log(ngx.ERR, "ngx.shared.domain_lock no memory")
        end
        if success then
            local ok, err = ngx.timer.at(0, __getSocketDomain, {url = ngx.var.socket_url, host = host})
            if not ok then ngx.log(ngx.ERR, "hostinfo() cont create ngx.timer err:", err) end
        end
    end
    return nil
end


-- 计算路径的md5路径
function M.md5path(uri)
    local md5 = ngx.md5(uri)
    local dir1, dir2 = md5:sub(1, 2), md5:sub(3, 4)
    return string.format("/%s/%s/%s", dir1, dir2, md5)
end

-- 递归创建缓存目录
function M.mkdir(path)
    local res, err = lfs.mkdir(path)
    if not res then
        local parent = path:gsub("/[^/]+/$", "/")
        if M.mkdir(parent) then
            local res, err = lfs.mkdir(path)
            if err ~= nil then ngx.log(ngx.ERR, "创建文件夹失败[".. path .. "]", err) end
            return res
        end
    end
    return res
end

-- 验证缓存是否过期
-- path 文件路径, expired 缓存时间
-- return boolean 是否有效
function M.cachevalid(path, expired)
    local modification, err  = lfs.attributes(path, "modification")
    if modification then
        local expired_time = expired * 60 + modification
        if expired_time > os.time() then
            return true
        end
    end
    return false
end

-- 给缓存加锁
-- return 是否存在锁
function M.cachelock(path)
    local success, err, forcible = ngx.shared.cache_lock:add(path, true, __sharedTime)
    if forcible then
        ngx.log(ngx.ERR, "ngx.shared.cache_lock no memory")
    end
    if err and err ~= "exists" then
        ngx.log(ngx.ERR, "ngx.shared.cache_lock err", err)
    end
    return success
end

-- 缓存成功
-- 调用端口处理缓存目录。
function M.cacheset(premature ,cacheData)
    local httpc = http.new()
    local res, err = httpc:request_uri(cacheData.url, {
        method = "POST",
        body = json.encode({
            SiteID = cacheData.identity,
            Path = cacheData.uri,
            File = cacheData.path,
            Size = cacheData.size,
            Accessed = os.time(),
            Expried = os.time() + (cacheData.time * 60)
        }),
        headers = {
            ["Content-Type"] = "application/json",
        },
    })
    if res.status ~=  200 then 
        ngx.log(ngx.ERR, "cacheset() err", res)
    end
end

-- 重新缓存文件
function M.redownload(premature, downData, cacheData)
    local httpc = http.new()
    local res, err = httpc:request_uri(downData.url, downData.params)
    if res.status == 200 then
        downData.file:seek("set")
        file:write(res.body)
        downData.file:close()
        M.cacheset(premature,cacheData)
    else
        os.remove(cacheData.path)
    end
    httpc:close()
end

return M
