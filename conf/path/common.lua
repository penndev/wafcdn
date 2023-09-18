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

local __getSocketSSL = function(premature, host)
    local success, err, forcible = ngx.shared.ssl_lock:add(host..".lock", true, __sharedTime)
    if err and err ~= "exists" then
        ngx.log(ngx.ERR, "ngx.shared.ssl_lock err:", err)
    end
    if forcible then
        ngx.log(ngx.ERR, "ngx.shared.ssl_lock no memory")
    end
    if not success then
        return nil
    end
    local httpc = http.new()
    local res, err = httpc:request_uri(M.getenv("SOCKET_API").."/socket/ssl?host="..host)
    if err then
        ngx.log(ngx.ERR, "__getSocketSSL() request_uri err:", err)
        return
    end
    if res and res.status == 200 then
        local certbase64, err = json.decode(res.body)
        if err then
            ngx.log(ngx.ERR, "sslinfo cjson decode err", err)
        end
        local crt = ngx.decode_base64(certbase64.crt)
        local key = ngx.decode_base64(certbase64.key)

        local success, err, forcible = ngx.shared.ssl:set(host, crt.. "$" ..key, __sharedTime)
        if err or not success then
            ngx.log(ngx.ERR, "ngx.shared.ssl set err:", err)
        end
        if forcible then
            ngx.log(ngx.ERR, "ngx.shared.ssl no memory")
        end
        return {crt = crt,key = key}
    else
        ngx.log(ngx.ERR, "__getSocketSSL() request_uri err:", res.status,  res.body)
    end
end

-- 获取证书信息
-- return cert{pem,key}
function M.sslinfo(host)
    local value, flags, stale = ngx.shared.ssl:get_stale(host)
    if value then -- 存在则直接返回。
        if stale then  -- 存在但是过期了
            local ok, err = ngx.timer.at(0, __getSocketSSL, host)
            if not ok then ngx.log(ngx.ERR, "sslinfo() cont create ngx.timer err:", err) end
        end
        local crt,key = value:match("(.-)%$(.+)")
        return {crt = crt,key = key}
    else --完全不存在.
        return __getSocketSSL(0,host)
    end
end

local __getSocketDomain = function(premature, host)
    -- 增加请求锁，避免耗尽资源 - 延后锁写法。会有问题换一种不遗漏的写法。
    local success, err, forcible = ngx.shared.domain_lock:add(host.."_lock", true, __sharedTime)
    if err and err ~= "exists" then -- 有异常情况。
        ngx.log(ngx.ERR, "ngx.shared.domain_lock err", err)
    end
    if forcible then
        ngx.log(ngx.ERR, "ngx.shared.domain_lock no memory")
    end
    if not success then
        return nil
    end
    -- 获取域名配置信息
    local httpc = http.new()
    local res, err = httpc:request_uri(M.getenv("SOCKET_API").."/socket/domain?host="..host)
    if err then
        ngx.log(ngx.ERR, "__getSocketDomain() request_uri err:", err)
        return
    end
    if res and res.status == 200 then
        local success, err, forcible = ngx.shared.domain:set(host, res.body, __sharedTime)
        if err or not success then 
            ngx.log(ngx.ERR, "ngx.shared.domain set err", err)
        end
        if forcible then
            ngx.log(ngx.ERR, "ngx.shared.domain_lock no memory")
        end
        return res.body
    else
        ngx.log(ngx.ERR, "__getSocketDomain() request_uri err:", res.status,  res.body)
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
        local config, err = json.decode(value)
        if err then
            ngx.log(ngx.ERR, "hostinfo() cjson decode err", err)
        end
        return config
    else
        local value = __getSocketDomain(0, host)
        if not value then
            return nil
        end
        local config, err = json.decode(value)
        if err then
            ngx.log(ngx.ERR, "hostinfo() cjson decode err", err)
        end
        return config
    end
end

function M.contentType(type)
    if type == "ts" then
        return "video/mp2t"
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
        local parent, count = path:gsub("/[^/]+/$", "/")
        if count ~= 1 then
            ngx.log(ngx.ERR, "创建文件夹失败[".. path .. "]", err)
            return nil
        end
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
function M.docache(premature,cacheData)
    local httpc = http.new()
    local res, err = httpc:request_uri(M.getenv("SOCKET_API").."/socket/docache", {
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
    if res.status ~=  200 then 
        ngx.log(ngx.ERR, "docache() err:", res.status, res.body, err)
    end
end

-- 刷新缓存访问
function M.upcache(premature, file, time) 
    local httpc = http.new()
    local res, err = httpc:request_uri(M.getenv("SOCKET_API").."/socket/upcache", {
        method = "POST",
        body = json.encode({
            File = file,
            Accessed = time,
        }),
        headers = {
            ["Content-Type"] = "application/json",
        }
    })
    if res.status ~=  200 then 
        ngx.log(ngx.ERR, "upcache() err:", res.status, res.body, err)
    end
end

-- 重新缓存文件
function M.redownload(premature, downData, cacheData)
    local httpc = http.new()
    local res, err = httpc:request_uri(downData.url, downData.params)
    if res.status == 200 then
        downData.file:seek("set")
        downData.file:write(res.body)
        downData.file:close()
        cacheData.size = tonumber(res.headers["Content-Length"])
        M.docache(premature,cacheData)
    else
        os.remove(cacheData.path)
    end
    httpc:close()
end

return M
