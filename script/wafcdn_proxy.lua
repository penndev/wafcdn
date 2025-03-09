local ngx = require("ngx")
local util = require("module.util")
local balancer = require("ngx.balancer")
local wafcdn = require("wafcdn")

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
    -- local proxy_start = string.len("/@proxy") + 1
    ngx.req.set_uri(string.sub(ngx.var.uri, 8), false)
    local proxy = util.json_decode(ngx.var.wafcdn_proxy)

    -- 请求缓存处理
    local wafcdn_proxy_cache = { time = 0, key = "", status = {} }
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
                    wafcdn_proxy_cache.time = cache.time
                    wafcdn_proxy_cache.uri = uri
                    wafcdn_proxy_cache.status = cache.status
                    break
                end
            end
        end
    end
    -- 查询是否存在缓存文件，重定向到缓存。
    if wafcdn_proxy_cache.time > 0 then
        -- 判断是否命中缓存 - 200返回文件路径与header头
        local res, _ = util.request("/@wafcdn/cache", {
            args={ site_id=ngx.var.wafcdn_site, method=ngx.var.request_method, uri=wafcdn_proxy_cache.uri, },
        })
        if res then -- 直接返回缓存内容
            ngx.say(util.json_encode(res))
            return
        else
            -- 30分钟仅缓存一次
            local value, flags = ngx.shared.cache_key:get(ngx.var.request_method..wafcdn_proxy_cache.uri)
            if value == nil then
                -- ngx.shared.cache_key:set(ngx.var.request_method..wafcdn_proxy_cache.uri, 1, 60*30)
                ngx.ctx.wafcdn_proxy_cache = wafcdn_proxy_cache
            end
        end
    end

    -- 反向代理连接方式
    -- pass_proxy or upstream
    if proxy.keepalive_requests == 0 then -- 走 pass_proxy
        ngx.var.wafcdn_proxy_server = proxy.server
    else
        -- 走 upstream
        local protocol, ip, port = string.match(proxy.server, "^(%w+)://([^:/]+):?(%d*)$")
        if protocol == "http" then
            ngx.var.wafcdn_proxy_server = "http://wafcdn_proxy_backend"
        elseif protocol == "https" then -- 回源协议是否是https
            ngx.var.wafcdn_proxy_server = "https://wafcdn_proxy_backend"
        else
            wafcdn.status(426, "proxy error")
            return
        end
        -- 设置反向代理连接池
        ngx.ctx.wafcdn_proxy_upstream = {
            ip = ip, port = port, host = proxy.host,
            keepalive_timeout = proxy.keepalive_timeout,
            keepalive_requests = proxy.keepalive_requests
        }
    end

    -- 设置回源请求头
    ngx.req.set_header("X-Real-IP", ngx.var.remote_addr)
    ngx.req.set_header("X-Real-Port", ngx.var.remote_port)
    ngx.req.set_header("X-Forwarded-For", ngx.var.proxy_add_x_forwarded_for)
    ngx.req.set_header("X-Forwarded-Port", ngx.var.server_port)
    -- 自定义回源请求头
    for key, val in pairs(proxy.header or {}) do
        ngx.req.set_header(key, val)
    end
    if proxy.host then -- 回源Host
        ngx.var.wafcdn_proxy_host = proxy.host
    end
end

-- 反向代理连接池
-- @param
    -- ngx.ctx.wafcdn_proxy_backend = "127.0.0.1:80" - 服务器
    -- ngx.ctx.wafcdn_proxy_upstream.host = "github.com" - 证书用
function WAFCDN_PROXY.balancer()
    if not ngx.ctx.wafcdn_proxy_upstream then
        ngx.log(ngx.ERR, "ngx.ctx.wafcdn_proxy_upstream nil")
        return ngx.exit(428)
    end

    -- SNI后端是https的话需要第三个参数host
    -- ok, err = balancer.set_current_peer(host, port, host?)
    local ok, err = balancer.set_current_peer(
        ngx.ctx.wafcdn_proxy_upstream.ip,
        ngx.ctx.wafcdn_proxy_upstream.port,
        ngx.ctx.wafcdn_proxy_upstream.host
    )
    if not ok then
        ngx.log(ngx.ERR, "failed to set the current peer: ", err)
        return ngx.exit(500)
    end
    -- 上游连接池
    -- ok, err = balancer.enable_keepalive(idle_timeout?, max_requests?)
    if ngx.ctx.wafcdn_proxy_upstream.keepalive_requests or 0 > 0 then
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

function WAFCDN_PROXY.header_filter()
    if ngx.ctx.wafcdn_proxy_cache and ngx.ctx.wafcdn_proxy_cache.status and util.contains(ngx.status, ngx.ctx.wafcdn_proxy_cache.status) then
        -- 缓存的key做md5
        local cache_key = ngx.md5(ngx.var.request_method .. ngx.ctx.wafcdn_proxy_cache.key)
        local dir1, dir2 = string.sub(cache_key, 1, 2), string.sub(cache_key, 3, 4)
        local cache_path = string.format("%s/%s/%s/%s/%s", "./data", ngx.var.wafcdn_site, dir1, dir2, cache_key)
        -- 创建缓存文件
        local file, err = io.open(cache_path, "wb")
        if not file then
            if util.mkdir(string.match(cache_path, "(.*)/")) then
                file, err = io.open(cache_path, "wb")
            end
            if not file then
                ngx.log(ngx.ERR, "cant open file:[", cache_path, "]", err)
            end
        end

        -- 操作缓存
        if file then
            ngx.ctx.docache = {
                header = ngx.resp.get_headers(), -- 响应头
                file = file, -- 文件句柄
                path = cache_path, -- 文件路径
                perfect = false, -- 是否完整
            }
        end
        ngx.header["Cache-Control"] = "max-age=" .. ngx.ctx.wafcdn_proxy_cache.time
    end
    wafcdn.header_filter()
end

-- 反向代理缓存
-- @param
    -- ngx.ctx.docache = { file = file, path = cache_path }
function WAFCDN_PROXY.body_filter()
    if ngx.ctx.docache and ngx.ctx.docache.file then
        ngx.ctx.docache.file:write(ngx.arg[1])
        if ngx.arg[2] == true then
            ngx.ctx.docache.perfect = true
        end
    end
end

-- 日志处理
function WAFCDN_PROXY.log()
    if ngx.ctx.docache and ngx.ctx.docache.file then
        ngx.ctx.docache.file:close()
        if  ngx.ctx.docache.perfect then
            -- 发送请求同步缓存状态
            local data = util.json_encode({
                site_id=ngx.var.wafcdn_site,
                method=ngx.var.request_method,
                uri=ngx.ctx.wafcdn_proxy_cache.uri,
                header=ngx.ctx.docache.header,
                path=ngx.ctx.docache.path,
            })
            local handle = function ()
                local res, err = util.request("/@wafcdn/cache", {
                    method = "PUT",
                    header = {
                        ["Content-Type"] = "application/json",
                    },
                    body = data
                })
                if not res then
                    ngx.log(ngx.ERR, "cache error: ", err)
                end
            end
            ngx.timer.at(0, handle)
        else
            os.remove(ngx.ctx.docache.path)
        end
    end
    --
end

return WAFCDN_PROXY
