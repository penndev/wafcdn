local common = require("common")

local config = common.hostinfo()
if config == nil then
    ngx.status = 403
    ngx.say("Error: Cant get host info!")
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
    local cache_hit = 0 -- [0未命中缓存|1命中缓存规则|2命中缓存文件]
    local cache_time = 0
    if config.cache ~= nil then
        for _, cache in ipairs(config.cache) do
            if string.match(ngx.var.uri, cache.cache_key) then
                cache_hit = 1
                cache_time = cache.cache_time
                break
            end
        end
    end

    if cache_hit == 1 and cache_time > 0 then
        local file_path = config.identity .. common.md5path(ngx.var.uri)
        local cache_path = ngx.var.cache_dir .. file_path
        if common.getcache(cache_path, cache_time) then
            ngx.req.set_uri("/@cached/"..file_path, true)
            return
        end
        if common.docachelock(cache_path, 300) then -- 给缓存行为加锁
            ngx.ctx.docache = true 
            ngx.ctx.cache_path = cache_path
        end
    end
end

ngx.ctx.back = config.back
