-- 判断防御和缓存相关的逻辑

-- 防御
    -- URL Header鉴权 功能通过设置鉴权算法和鉴权key来对数据进行访问保护。
    -- Referer 开启防盗链白名单，黑名单。
    -- IP 白名单，黑名单。
    -- UA 白名单，黑名单。
    -- 请求限制(限速/QPS)

-- 缓存

local common = require("common")

local config = common.hostinfo(ngx.var.host)
-- !!这里验证config

-- 判断是否有缓存规则
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

    -- 验证文件缓存，超过一天的内容则文件缓存。
    if cache_hit == 1 and cache_time > 0 then
        local file_path = config.dir .. common.md5path(ngx.var.uri)
        local cache_path = ngx.var.cache_path .. file_path
        if common.getcache(cache_path, cache_time) then
            ngx.req.set_uri("/@cached/"..file_path, true)
            return
        end
        -- 给缓存行为加锁
        local success, err, forcible = ngx.shared.docache:add(cache_path, true, 300)
        if forcible then
            ngx.log(ngx.ERR, "ngx.shared.docache no memory")
        end
        if success then -- 明确告诉下一步必须缓存
            ngx.ctx.docache = true 
            ngx.ctx.cache_path = cache_path
        elseif err ~= "exists" then
            ngx.log(ngx.ERR, "ngx.shared.docache" .. err)
        end
    end
end


ngx.ctx.back = config.back
