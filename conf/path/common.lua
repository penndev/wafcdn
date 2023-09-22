-- 公共方法模块
local M = {}

local envTable = {}
local envfile = io.open(".env", "r")
if not envfile then
    error("can't load the .env file")
end
for line in envfile:lines() do
    local key, value = line:gsub("^%s*(.-)%s*$", "%1"):match("^([^=]+)=(.+)$")
    if key and value then
        envTable[key] = value
    end
end

function M.getenv(key)
    return envTable[key]
end

local __sharedTime = tonumber(envTable["SHARED_TTL"])
if __sharedTime < 30 then
    __sharedTime = 300
end

local lfs = require("lfs")
local http = require("http")
local json = require("cjson")
local lock = require("resty.lock")

local __getSocketSSL = function(premature, host)
    local my_lock = lock:new("ssl_lock")
    if not my_lock then
        ngx.log(ngx.ERR, "cant create ssl_lock ")
        return
    end

    local ok, err = my_lock:lock(host)
    if not ok then
        ngx.log(ngx.ERR, "cant lock ssl_lock ", err)
        return
    end
    -- 是否有人获取了结果已经，如果有，我是缓存的等待者。
    local value, _ = ngx.shared.ssl:get(host)
    if value then
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock ssl_lock: ", err)
        end
        local crt, key = tostring(value):match("(.-)%$(.+)")
        return { crt = crt, key = key }
    end
    -- 强制限制避免回源失败的缓存穿透
    local success, err, forcible = ngx.shared.ssl_lock:add(host .. ".lock", true, __sharedTime)
    if err and err ~= "exists" then
        ngx.log(ngx.ERR, "ngx.shared.ssl_lock err:", err)
    end
    if forcible then
        ngx.log(ngx.ERR, "ngx.shared.ssl_lock no memory")
    end
    if not success then
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock ssl_lock: ", err)
        end
        return nil
    end
    -- 没有人获取结果，那么我就是缓存的执行者
    local httpc = http.new()
    if not httpc then
        ngx.log(ngx.ERR, "http.new return nil")
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock ssl_lock: ", err)
        end
        return nil
    end
    local res, err = httpc:request_uri(M.getenv("SOCKET_API") .. "/socket/ssl?host=" .. host)
    if not res then
        ngx.log(ngx.ERR, "__getSocketSSL() request_uri err:", err)
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock ssl_lock: ", err)
        end
        return
    end
    if res.status == 200 then
        local certbase64, err = json.decode(res.body)
        if err then
            ngx.log(ngx.ERR, "sslinfo cjson decode err", err)
        end
        local crt = ngx.decode_base64(certbase64.crt)
        local key = ngx.decode_base64(certbase64.key)
        local success, err, forcible = ngx.shared.ssl:set(host, crt .. "$" .. key, __sharedTime)
        if err or not success then
            ngx.log(ngx.ERR, "ngx.shared.ssl set err:", err)
        end
        if forcible then
            ngx.log(ngx.ERR, "ngx.shared.ssl no memory")
        end
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock ssl_lock: ", err)
        end
        return { crt = crt, key = key }
    else
        ngx.log(ngx.INFO, "status:", res.status, "|body:", res.body)
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock ssl_lock: ", err)
        end
    end
end

-- 获取证书信息
-- return cert{pem,key}
function M.sslinfo(host)
    local value, flags, stale = ngx.shared.ssl:get_stale(host)
    if value then     -- 存在则直接返回。
        if stale then -- 存在但是过期了
            local ok, err = ngx.timer.at(0, __getSocketSSL, host)
            if not ok then ngx.log(ngx.ERR, "sslinfo() cont create ngx.timer err:", err) end
        end
        local crt, key = tostring(value):match("(.-)%$(.+)")
        return { crt = crt, key = key }
    else --完全不存在.
        return __getSocketSSL(0, host)
    end
end

local __getSocketDomain = function(premature, host)
    local my_lock = lock:new("domain_lock")
    if not my_lock then
        ngx.log(ngx.ERR, "cant create domain_lock ")
        return
    end

    local elapsed, err = my_lock:lock(host)
    if not elapsed then
        ngx.log(ngx.ERR, "cant lock domain_lock ", err)
        return
    end
    -- 锁的等待者执行。
    local value, _ = ngx.shared.domain:get(host)
    if value then
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock domain_lock: ", err)
        end
        return value
    end
    -- 强制限制避免回源失败的缓存穿透
    local success, err, forcible = ngx.shared.domain:add(host .. ".lock", true, __sharedTime)
    if err and err ~= "exists" then
        ngx.log(ngx.ERR, "ngx.shared.domain err:", err)
    end
    if forcible then
        ngx.log(ngx.ERR, "ngx.shared.domain no memory")
    end
    if not success then
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock domain: ", err)
        end
        return nil
    end
    -- 再次后台获取
    local httpc = http.new()
    if not httpc then
        ngx.log(ngx.ERR, "http.new return nil")
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock domain_lock: ", err)
        end
        return nil
    end
    local res, err = httpc:request_uri(M.getenv("SOCKET_API") .. "/socket/domain?host=" .. host)
    if not res then
        ngx.log(ngx.ERR, "__getSocketDomain() request_uri err:", err)
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock domain_lock: ", err)
        end
        return nil
    end
    if res.status == 200 then
        local success, err, forcible = ngx.shared.domain:set(host, res.body, __sharedTime)
        if err or not success then
            ngx.log(ngx.ERR, "ngx.shared.domain set err", err)
        end
        if forcible then
            ngx.log(ngx.ERR, "ngx.shared.domain_lock no memory")
        end
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock domain_lock: ", err)
        end
        return res.body
    else
        ngx.log(ngx.ERR, "status:", res.status, "|body:", res.body)
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock domain_lock: ", err)
        end
    end
end

-- 获取域名的配置信息
-- return config{id,back,cache}
function M.hostinfo(host)
    local value, flags, stale = ngx.shared.domain:get_stale(host)
    if value then -- 存在则直接返回。
        if stale then
            local ok, err = ngx.timer.at(0, __getSocketDomain, host)
            if not ok then ngx.log(ngx.ERR, "hostinfo() cont create ngx.timer err:", err) end
        end
        return json.decode(tostring(value))
    else
        local value = __getSocketDomain(0, host)
        if not value then
            return nil
        end
        local config, err = json.decode(tostring(value))
        if err then
            ngx.log(ngx.ERR, "hostinfo() cjson decode err", err)
        end
        return config
    end
end

-- function M.contentType(type)
--     if type == "ts" then
--         return "video/mp2t"
--     end
--     return nil
-- end

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
        if lfs.attributes(path, 'mode') == 'directory' then
            return true
        end
        local parent, count = string.gsub(path, "/[^/]+$", "")
        if count ~= 1 then
            ngx.log(ngx.ERR, "创建文件夹失败[" .. path .. "]", parent, err)
            return nil
        end
        if M.mkdir(parent) then
            local res, err = lfs.mkdir(path)
            if not res then
                ngx.log(ngx.ERR, "创建文件夹失败[" .. path .. "]", err)
            end
            return res
        end
    end
    return res
end

-- 验证缓存是否过期
-- path 文件路径, expired 缓存时间
-- return boolean 是否有效
function M.cachevalid(path, expired)
    local modification, err = lfs.attributes(path, "modification")
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
function M.docache(premature, cacheData)
    local httpc = http.new()
    if not httpc then
        ngx.log(ngx.ERR, "http.new return nil")
        return nil
    end
    local res, err = httpc:request_uri(M.getenv("SOCKET_API") .. "/socket/docache", {
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
        }
    })
    if not res then
        ngx.log(ngx.ERR, err)
        return nil
    end
    if res.status ~= 200 then
        ngx.log(ngx.ERR, "status:", res.status, "|body:", res.body)
    end
end

-- 刷新缓存访问
function M.upcache(premature, file, time)
    local httpc = http.new()
    if not httpc then
        ngx.log(ngx.ERR, "http.new return nil")
        return nil
    end
    local res, err = httpc:request_uri(M.getenv("SOCKET_API") .. "/socket/upcache", {
        method = "POST",
        body = json.encode({
            File = file,
            Accessed = time,
        }),
        headers = {
            ["Content-Type"] = "application/json",
        }
    })
    if not res then
        ngx.log(ngx.ERR, err)
        return nil
    end
    if res.status ~= 200 then
        ngx.log(ngx.ERR, "status:", res.status, "|body:", res.body)
    end
end

-- 重新缓存文件
function M.redownload(premature, req, cacheMeta)
    local httpc = http.new()
    if not httpc then
        ngx.log(ngx.ERR, "http.new return nil")
        return nil
    end
    local res, err = httpc:request_uri(req.url, req.params)
    if not res then
        ngx.log(ngx.ERR, "http.request_uri return nil", err)
        return nil
    end
    if res.status == 200 then
        req.file:seek("set", 0)
        req.file:write(res.body)
        req.file:close()
        cacheMeta.size = tonumber(res.headers["Content-Length"])
        M.docache(premature, cacheMeta)
    else
        ngx.log(ngx.ERR, req.url, " cant download | status:", res.status)
        req.file:close()
        local success, err = os.remove(cacheMeta.path)
        if not success then
            ngx.log(ngx.ERR, "cant remove cache file ", err)
        end
    end
    httpc:close()
end

return M
