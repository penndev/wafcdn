local common = require("common")
local json = require("cjson")

-- 获取域名配置
local config = common.hostinfo(ngx.var.host)
if config == nil then -- 没有获取到域名配置
    ngx.status = 403
    ngx.say("cant load the domain config")
    return ngx.exit(403)
end

-- 处理防御防御
-- URL Header鉴权 功能通过设置鉴权算法和鉴权key来对数据进行访问保护。
-- Referer 开启防盗链白名单，黑名单。
-- IP 白名单，黑名单。
-- UA 白名单，黑名单。
-- 请求限制(限速/QPS)

-- 处理请求缓存
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
        local filepath = config.identity .. common.md5path(ngx.var.uri)
        local doCacheFilePath = common.getenv("CACHE_DIR") .. "/" .. filepath
        if common.cachevalid(doCacheFilePath, doCacheTime) then --缓存命中
            -- 适配文件类型
            -- local contentType = common.contentType(ngx.var.uri:match("%.([a-zA-Z0-9]+)$"))
            -- if contentType then
            --     table.insert(config.backend.resp_header, { name = "Content-Type", value = contentType })
            -- end
            ngx.req.set_uri_args({
                cache_file = doCacheFilePath,
                resp_header = json.encode(config.backend.resp_header)
            })
            ngx.req.set_uri("/@cache", true)
            return
        end
        if common.cachelock(doCacheFilePath) then -- 给缓存行为加锁
            ngx.ctx.docache = true
            ngx.ctx.docachefilepath = doCacheFilePath
            ngx.ctx.docachetime = doCacheTime
            ngx.ctx.docacheidentity = config.identity
        end
    end
end
-- 处理回源
ngx.ctx.backend = config.backend
