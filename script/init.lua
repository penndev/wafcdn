require("ngx.ssl")
require("resty.lock")
require("lfs")
require("cjson")
require("http")

local ngx = require("ngx")

local util = require("util")

-- 检查参数
local sharedttl = tonumber(util.getenv("SHARED_TTL"))
if not sharedttl or sharedttl < 5 or sharedttl > 600 then
    error("set env SHARED_TTL net < 5 and > 600")
end

local domainttl = tonumber(util.getenv("DOMAIN_TTL"))
if not domainttl or domainttl < 5 or domainttl > 600 then
    error("set env DOMAIN_TTL net < 5 and > 600")
end

local socketapi = util.getenv("SOCKET_API")
if not socketapi then
    error("cant get env SOCKET_API")
end

local cachedir = util.getenv("CACHE_DIR")
if not cachedir then
    error("cant get env CACHE_DIR")
end

local upcachelimit = tonumber(util.getenv("UPCACHE_LIMIT_COUNT"))
if not upcachelimit then
    error("cant get env UPCACHE_LIMIT_COUNT")
end

---设置没有缓存配置的处理hook
local function setNotFoundDomain()
    ngx.status = 403
    ngx.say("cant load the domain config")
    ngx.exit(403)
end

return {
    sharedttl = sharedttl, -- 通用缓存生存时间/秒 [刷新热度，文件缓存加锁]
    domainttl = domainttl, -- 域名缓存时间/秒 [ssl证书，配置域名信息]
    socketapi = socketapi, -- 控制后台api
    cachedir = cachedir, -- 缓存的控制目录
    upcachelimit = upcachelimit, -- 刷新热度 访问/次

    setNotFoundDomain = setNotFoundDomain,
    serverFlagDocache = "wafcdn#docache",
    serverFlagBackend = "wafcdn#backend",
    serverFlagCache = "wafcdn#cache",
}
