local ngx = require("ngx")
local response = require("response")
local util = require("util")
local filter = require("filter")
local balancer = require("ngx.balancer")

local WAFCDN = {}

function WAFCDN.rewrite()
    local host = ngx.var.host
    if not host then
        response.status(400, "01")
        return
    end

    -- -- -- -- -- -- -- -- -- 
    -- !IP黑名单处理
    -- !IP区域控制
    -- !User-Agent设备控制列表
    -- !Referer 引用控制
    -- -- -- -- -- -- -- -- -- 

    -- 获取后台配置
    local res, err = util.request( "/@wafcdn/domain", {args={host=ngx.var.host}})
    if res == nil then
        response.status(406, "Domain Not Found")
        return
    end
    
    -- rate单链接限速，并发请求限速。
    local limit = res.body.security.limit
    if limit.status == true then
        local allow = filter.limit(limit.rate, limit.queries / limit.seconds, limit.queries)
        if not allow then
            response.status(429, "Too Many Requests")
            return
        end
    end

    -- 接口验签
    local sign = res.body.security.sign
    if sign.status == true then
        local allow, err = filter.sign(sign.method, sign.key, sign.expireargs, sign.signargs)
        if not allow then
            response.status(403, "Forbidden " .. err)
            return
        end
    end
    
    -- 从其他地方重定向过来的 会在原本请求url中添加 /rewrite
    -- 但是ngx.var.request_uri未改变，
    -- 所以可以对比开头来判断是否是重定向过来的
    if string.sub(ngx.var.uri, 0, 9) == "/rewrite/" then
        if string.sub(ngx.var.request_uri, 0, 9) ~= "/rewrite/" then 
            ngx.req.set_uri(string.sub(ngx.var.uri, 9), false)
        end
    end

    ngx.var.wafcdn_site = res.body.site
    -- 
    -- 路由
    -- 
    if res.body.type == "static" then
        ngx.var.wafcdn_static = util.json_encode(res.body.static)
        ngx.req.set_uri("/@static" .. ngx.var.uri, true)
        return
    elseif res.body.type == "proxy" then
        ngx.var.wafcdn_proxy = util.json_encode(res.body.proxy)
        -- ngx.say(ngx.var.wafcdn_proxy)
        ngx.req.set_uri("/@proxy" .. ngx.var.uri, true)
        return
    else 
        response.status(403, "SiteType")
        return
    end
end

-- 静态文件目录访问
function WAFCDN.static_access()
    -- 用户直接输入访问 /@static
    if ngx.var.wafcdn_static == "" then 
        ngx.exec("/rewrite"..ngx.var.uri)
        return
    end
    -- 修复移除添加路由的
    local static_start = string.len("/@static") + 1
    ngx.req.set_uri(string.sub(ngx.var.uri, static_start), false)
    local static = util.json_decode(ngx.var.wafcdn_static)
    -- 静态文件目录
    ngx.var.wafcdn_static_root = static.root
    return
end

-- 反向代理配置
-- 查看缓存命中还是后端请求
-- @request
    -- ngx.var.wafcdn_proxy 配置的json字符串防止内部跳转ctx丢失
-- @set 
    -- ngx.var.wafcdn_proxy_server 动态回源协议
    -- ngx.var.wafcdn_proxy_host 回源host
function WAFCDN.proxy_access()
    if ngx.var.wafcdn_proxy == "" then 
        ngx.exec("/rewrite"..ngx.var.uri)
        return
    end
    local proxy_start = string.len("/@proxy") + 1
    ngx.req.set_uri(string.sub(ngx.var.uri, proxy_start), false)
    local proxy = util.json_decode(ngx.var.wafcdn_proxy)

    -- 回源协议是否是https
    -- 回源请求头
    ngx.var.wafcdn_proxy_server = "http://wafcdn_proxy_backend"
    if proxy.protocol == "https" then
        ngx.var.wafcdn_proxy_server = "https://wafcdn_proxy_backend"
    end
    ngx.req.set_header("X-Real-IP", ngx.var.remote_addr)
    ngx.req.set_header("X-Real-Port", ngx.var.remote_port)
    ngx.req.set_header("X-Forwarded-For", ngx.var.proxy_add_x_forwarded_for)
    ngx.req.set_header("X-Forwarded-Port", ngx.var.server_port)
    for key, val in pairs(proxy.header) do
        ngx.req.set_header(key, val)
    end
    if proxy.host ~= "" then
        ngx.var.wafcdn_proxy_host = proxy.host
    end
    
    local cache_time = 0 --缓存过期时间秒
    if proxy.cache then
        for _, cache in ipairs(proxy.cache) do
            if cache.ruth and ngx.var.uri:match(cache.ruth) then
                cache_time = cache.time
                break
            end
        end
    end
    ngx.say(cache_time)

    -- 设置反向代理连接池
    ngx.ctx.wafcdn_proxy_upstream = {
        server = proxy.server,
        host = proxy.host,
        keepalive_timeout = proxy.keepalive_timeout,
        keepalive_requests = proxy.keepalive_requests
    }
    return
end

-- 反向代理连接池
-- @param
    -- ngx.ctx.wafcdn_proxy_backend:[host:port] = "127.0.0.1:80"
    -- 
function WAFCDN.proxy_upstream()
    -- 上游服务器
    local ip, port = string.match(ngx.ctx.wafcdn_proxy_upstream.server, "([^:]+):(%d+)")
    -- SNI后端是https的话需要第三个参数host
    -- ok, err = balancer.set_current_peer(host, port, host?)
    local ok, err = balancer.set_current_peer(ip, port, ngx.ctx.wafcdn_proxy_upstream.host)
    if not ok then
        ngx.log(ngx.ERR, "failed to set the current peer: ", err)
        return ngx.exit(500)
    end
    -- 上游连接池
    -- ok, err = balancer.enable_keepalive(idle_timeout?, max_requests?)
    ok, err = balancer.enable_keepalive(
        ngx.ctx.wafcdn_proxy_upstream.keepalive_timeout, 
        ngx.ctx.wafcdn_proxy_upstream.keepalive_requests
    )
    if not ok then
        ngx.log(ngx.ERR, "failed to set keepalive: ", err)
        return
    end 

end


function WAFCDN.log(location)
    -- 获取客户端 IP 地址
    local ip = ngx.var.remote_addr
    local request_method = ngx.var.request_method
    local request_uri = ngx.var.request_uri
    local status = ngx.var.status
    local time = ngx.localtime()
    ngx.log(ngx.ERR, location, " Time: ", time, " | IP: ", ip, " | Method: ", request_method, " | URI: ", request_uri, " | Status: ", status)
end


return WAFCDN
