local ngx = require("ngx")
local util = require("util")
local balancer = require("ngx.balancer")

local WAFCDN_PROXY = {}

-- 反向代理配置 
-- !!! 必须使用rewrite 因为子请求会绕过access !!!
-- 查看缓存命中还是后端请求
-- @request
    -- ngx.var.wafcdn_proxy 配置的json字符串防止内部跳转ctx丢失
-- @set 
    -- ngx.var.wafcdn_proxy_server 动态回源协议
    -- ngx.var.wafcdn_proxy_host 回源host
function WAFCDN_PROXY.rewrite()
    if ngx.var.wafcdn_proxy == "" then 
        ngx.exec("/rewrite"..ngx.var.uri)
        return
    end
    local proxy_start = 8 --string.len("/@proxy") + 1
    ngx.req.set_uri(string.sub(ngx.var.uri, proxy_start), false)
    local proxy = util.json_decode(ngx.var.wafcdn_proxy)

    
    -- 请求缓存处理
    ngx.ctx.wafcdn_proxy_cache = { time = 0, key = "", status = {} }
    if proxy.cache then
        for _, cache in ipairs(proxy.cache) do
            -- 是否匹配缓存方法 GET,POST
            if util.contains(ngx.var.request_method, cache.method) then
                -- 是否忽略参数
                local uri = ngx.var.uri
                if cache.args == true then
                    uri = ngx.var.request_uri
                end
                -- 缓存规则是否命中
                if cache.ruth and string.match(ngx.var.uri, cache.ruth) then
                    ngx.ctx.wafcdn_proxy_cache.time = cache.time
                    ngx.ctx.wafcdn_proxy_cache.key = uri
                    ngx.ctx.wafcdn_proxy_cache.status = cache.status
                    break
                end
            end
        end
    end
    -- 缓存规则命中
    if ngx.ctx.wafcdn_proxy_cache.time > 0 then
        -- 判断是否命中缓存
        -- 直接返回缓存内容
        -- return
    end
    

    if proxy.keepalive_requests == 0 then
        ngx.var.wafcdn_proxy_server = proxy.server
    else
        local protocol, ip, port = string.match(url, "^(%w+)://([^:/]+):?(%d*)$")
        -- 移动到这里
    end

    -- 回源Host
    if proxy.host then
        ngx.var.wafcdn_proxy_host = proxy.host
    end

    -- 默认 ngx.var.wafcdn_proxy_server = "http://wafcdn_proxy_backend"
    -- 回源协议是否是https
    if proxy.protocol == "https" then
        ngx.var.wafcdn_proxy_server = "https://wafcdn_proxy_backend"
    end
    ngx.req.set_header("X-Real-IP", ngx.var.remote_addr)
    ngx.req.set_header("X-Real-Port", ngx.var.remote_port)
    ngx.req.set_header("X-Forwarded-For", ngx.var.proxy_add_x_forwarded_for)
    ngx.req.set_header("X-Forwarded-Port", ngx.var.server_port)
    -- 回源请求头 
    for key, val in pairs(proxy.header) do
        ngx.req.set_header(key, val)
    end



    -- 设置反向代理连接池
    ngx.ctx.wafcdn_proxy_upstream = {
        server_ip = proxy.server,
        server_port = proxy.server,
        host = proxy.host,
        keepalive_timeout = proxy.keepalive_timeout,
        keepalive_requests = proxy.keepalive_requests
    }
    return
end
    
-- 反向代理连接池
-- @param
    -- ngx.ctx.wafcdn_proxy_backend = "127.0.0.1:80" - 服务器
    -- ngx.ctx.wafcdn_proxy_upstream.host = "github.com" - 证书用
function WAFCDN_PROXY.balancer()
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
    if ngx.ctx.wafcdn_proxy_upstream.keepalive_requests > 0 then
        ok, err = balancer.enable_keepalive(
            ngx.ctx.wafcdn_proxy_upstream.keepalive_timeout, 
            ngx.ctx.wafcdn_proxy_upstream.keepalive_requests
        )
        if not ok then
            ngx.log(ngx.ERR, "failed to set keepalive: ", err)
            return
        end         
    end
end


return WAFCDN_PROXY