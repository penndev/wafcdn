local ngx = require("ngx")
local util = require("util")
local lfs = require("lfs")
local balancer = require("ngx.balancer")
local init = require("init")

local WAFCDN_PROXY = {}

-- 是否需要缓存
-- @param proxy
-- @return table
    -- time 缓存时间
    -- key 缓存key
    -- status 缓存状态
    -- uri 缓存uri
function WAFCDN_PROXY.ROUTE(proxy)
    -- 生命周期传递参数
    local wafcdn_proxy_cache = {}
    wafcdn_proxy_cache.time = 0 -- 是否需要缓存如果<=0则不需要缓存
    wafcdn_proxy_cache.uri = "" -- 缓存的链接，不包含域名，根据缓存规则来判断是否包含参数
    wafcdn_proxy_cache.status = {} -- 只缓存固定的状态码，如果返回502则不缓存
    wafcdn_proxy_cache.xCache = "" -- 缓存状态字符串

    -- 只处理 wafcdn_proxy_cache.time 用来验证是否匹配缓存
    if proxy.cache then
        for _, cache in ipairs(proxy.cache) do
            -- 支持PURGE方法 快速清理缓存
            if proxy.cache_purge then
                table.insert(cache.method, "PURGE")
            end
            -- 是否包含了缓存方法 GET,POST
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

    -- 判断是否缓存命中文件 如果命中缓存，则proxy代理的生命周期结束。
    if wafcdn_proxy_cache.time > 0 then
        -- 客户端主动清理缓存请求PURGE
        if ngx.var.request_method == "PURGE" then
            local res, err = util.request("/@wafcdn/purge", {
                query={ 
                    site_id=ngx.var.wafcdn_site,
                    uri = wafcdn_proxy_cache.uri
                },
            })
            if err ~= nil then
                util.status(202, err)
                return
            end
            util.status(200, res.body)
            return
        end

        local res, _ = util.request("/@wafcdn/cache", {
            query={ site_id=ngx.var.wafcdn_site, method=ngx.var.request_method, uri = wafcdn_proxy_cache.uri},
            cache=1
        })
        -- 验证缓存文件是否存在。并在有效期内
        if res then
            local cacheAge = ngx.time() - res.body.time
            if cacheAge < wafcdn_proxy_cache.time then
                -- 缓存命中 添加返回头
                res.body.header["Cache-Control"] = "max-age=" .. wafcdn_proxy_cache.time
                res.body.header["Age"] = cacheAge
                res.body.header["X-Cache"] = "HIT"
                -- 清理掉一些上游缓存头
                -- 目标清除的 header 键列表
                local to_clear = {
                    connection = true,
                    ["content-length"] = true,
                    ["accept-ranges"] = true,
                }
                for key, _ in pairs(res.body.header) do
                    if to_clear[string.lower(key)] then
                        res.body.header[key] = nil
                    end
                end
                ngx.var.wafcdn_header = util.header_merge(res.body.header)
                ngx.var.wafcdn_alias = util.json_encode({file = res.body.path})
                -- 返回静态文件 ngx.req.set_uri 不会执行任何的后续操作
                ngx.req.set_uri("/@alias", true)
            else
                wafcdn_proxy_cache.xCache = "EXPIRED"
            end
        else
            wafcdn_proxy_cache.xCache = "MISS"
        end

        -- 仅缓存一次 不然会形成竞争。
        local cache_lock = util.cache_path(ngx.var.request_method, wafcdn_proxy_cache.uri)..".lock"
        local attr = lfs.attributes(cache_lock)
        if attr then
            local cacheWait = ngx.time() - attr.modification
            wafcdn_proxy_cache.xCache = "BYPASS,CacheLock-".. tostring(cacheWait)
            if cacheWait > 3600 then -- 超过一个小时还在缓存的文件
                os.remove(cache_lock)
            end
            wafcdn_proxy_cache.time = 0
        end
    end
    proxy.cache = wafcdn_proxy_cache
    ngx.var.wafcdn_proxy = util.json_encode(proxy)
    ngx.req.set_uri("/@proxy" .. ngx.var.uri, true)
end

-- 反向代理配置
-- !!! 必须使用rewrite 因为子请求会绕过access !!!
function WAFCDN_PROXY.rewrite()
    if ngx.var.wafcdn_proxy == "" then
        ngx.exec("/rewrite"..ngx.var.uri)
        return
    end

    ngx.req.set_uri(string.sub(ngx.var.uri, 8), false) -- string.len("/@proxy") + 1
    local proxy, _ = util.json_decode(ngx.var.wafcdn_proxy)
    if proxy == nil then
        util.status(500, "INTERNAL_PROXY_JSON_FAIL")
        return
    end

    -- 反向代理连接方式
    -- pass_proxy or upstream
    -- 走 pass_proxy 必须走upstream
    -- proxy_http_version 无法动态配置
    if proxy.keepaliveRequests == 0 then
        util.status(500, "INTERNAL_PROXY_REQUESTS_CONFIG_FAIL")
        return
    else
        -- 走 upstream
        local protocol, ip, port = string.match(proxy.server, "^(%w+)://([^:/]+):?(%d*)$")
        if protocol == "http" then
            ngx.var.wafcdn_proxy_server = "http://wafcdn_proxy_backend"
        elseif protocol == "https" then -- 回源协议是否是https
            ngx.var.wafcdn_proxy_server = "https://wafcdn_proxy_backend"
        else
            util.status(426, "proxy error")
            return
        end
        -- 设置反向代理连接池
        ngx.ctx.wafcdn_proxy_upstream = {
            ip = ip, port = port, host = proxy.host,
            keepalive_timeout = proxy.keepaliveTimeout,
            keepalive_requests = proxy.keepaliveRequests
        }
    end
    -- 设置回源请求头
    -- ngx.req.set_header("X-Real-IP", ngx.var.remote_addr)
    -- ngx.req.set_header("X-Real-Port", ngx.var.remote_port)
    -- ngx.req.set_header("X-Forwarded-For", ngx.var.proxy_add_x_forwarded_for)
    -- ngx.req.set_header("X-Forwarded-Port", ngx.var.server_port)
    -- 自定义回源请求头
    for key, val in pairs(proxy.header or {}) do
        ngx.req.set_header(key, val)
    end
    if proxy.host and proxy.host ~= "" then -- 回源Host
        ngx.var.wafcdn_proxy_host = proxy.host
    end

    -- 缓存配置
    ngx.ctx.wafcdn_proxy_cache = proxy.cache
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
    -- 是否需要缓存文件
    -- 是否命中响应状态
    if ngx.ctx.wafcdn_proxy_cache.time > 0 and util.contains(ngx.status, ngx.ctx.wafcdn_proxy_cache.status) then
        -- 缓存的key做md5
        local cache_path = util.cache_path(ngx.var.request_method, ngx.ctx.wafcdn_proxy_cache.uri)
        -- 创建缓存文件
        local file, err = io.open(cache_path..".lock", "wb")
        if not file then
            if util.mkdir(string.match(cache_path, "(.*)/")) then
                file, err = io.open(cache_path..".lock", "wb")
            end
            if not file then
                ngx.log(ngx.ERR, "cant open file:[", cache_path..".lock", "]", err)
            end
        end

        -- 操作缓存
        if file then
            local header = ngx.resp.get_headers(100, true)
            ngx.ctx.docache = {
                header = header,-- 响应头
                file = file, -- 文件句柄
                path = cache_path, -- 文件路径
                perfect = false, -- 是否完整
                time = ngx.time() -- 缓存时间
            }
        end
    end
    ngx.header["X-Cache"] = ngx.ctx.wafcdn_proxy_cache.xCache
    util.header_response()
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
    -- 处理缓存文件管理
    if ngx.ctx.docache and ngx.ctx.docache.file then
        ngx.ctx.docache.file:close()
        -- 去除.lock文件名 让远程接口操作。来控制缓存管理
        -- os.rename(ngx.ctx.docache.path..".lock", ngx.ctx.docache.path)
        if ngx.ctx.docache.perfect then
            -- 发送请求同步缓存状态
            local data = {
                site_id= tonumber(ngx.var.wafcdn_site),
                method=ngx.var.request_method,
                uri=ngx.ctx.wafcdn_proxy_cache.uri,
                header=ngx.ctx.docache.header,
                path=ngx.ctx.docache.path,
                time=ngx.ctx.docache.time
            }
            local handle = function ()
                local res, err = util.request("/@wafcdn/cache", {
                    method = "PUT",
                    headers = {
                        ["Content-Type"] = "application/json",
                    },
                    body = util.json_encode(data)
                })
                if not res or res.status ~= 200 then
                    ngx.log(
                        ngx.ERR,
                        " || route:", "/@wafcdn/cache",
                        " || request:", util.json_encode(data),
                        " || response:", util.json_encode(res),
                        " || err:", err
                    )
                end
            end
            ngx.timer.at(0, handle)
        else
            os.remove(ngx.ctx.docache.path)
        end
    end
    -- 通用日志处理
    util.log()
end

return WAFCDN_PROXY
