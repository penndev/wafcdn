require("ngx.ssl")
require("resty.lock")

local lfs = require("lfs")
local util = require("util")
util.loadenv(".env")

-- 检查参数
local sharedttl = tonumber(util.getenv("SHARED_TTL"))
if not sharedttl or sharedttl < 5 or sharedttl > 600 then
    error("set env SHARED_TTL net < 5 and > 600")
end

local socketapi = util.getenv("SOCKET_API")
if not socketapi then
    error("cant get env SOCKET_API")
end

local cachedir = util.getenv("CACHE_DIR")
if not cachedir then
    error("cant get env CACHE_DIR")
end



---设置没有缓存配置的处理hook 
local function setNotFoundDomain()
    ngx.status = 403
    ngx.say("cant load the domain config")
    ngx.exit(403)
end


return {
    sharedttl = sharedttl,
    socketapi = socketapi,
    cachedir = cachedir,
    setNotFoundDomain = setNotFoundDomain,
    serverFlagDocache = "wafcnd#docache",
    serverFlagBackend = "wafcnd#backend",
    serverFlagCache = "wafcnd#cache",
}