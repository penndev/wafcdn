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
    -- 定义生命周期传递的缓存参数
    local wafcdn_proxy_cache = {
        time = 0,    -- 是否需要缓存，如果 <=0 则不缓存
        uri = "",    -- 缓存的 key，通常是请求 URI
        status = {}, -- 允许缓存的状态码列表，例如 {200, 206}，不缓存 502/503 等
        xCache = "", -- 返回给客户端的 X-Cache 字符串
        path = "",   -- 缓存的文件路径
    }

    -- 当前判断仅处理 wafcdn_proxy_cache.time 用来验证是否匹配缓存
    if proxy.cache then
        for _, cache in ipairs(proxy.cache) do
            if proxy.cache_purge then -- 支持PURGE方法 快速清理缓存
                table.insert(cache.method, "PURGE")
            end
            if util.contains(ngx.var.request_method, cache.method) then -- 是否包含了缓存方法 GET,POST
                local uri = ngx.var.uri
                if cache.args == true then                              -- 是否忽略参数
                    uri = ngx.var.request_uri
                end
                if cache.ruth and string.match(ngx.var.uri, cache.ruth) then -- 缓存规则是否命中
                    wafcdn_proxy_cache.time = cache.time
                    wafcdn_proxy_cache.uri = uri
                    wafcdn_proxy_cache.status = cache.status
                    wafcdn_proxy_cache.path = util.cache_path(ngx.var.request_method, wafcdn_proxy_cache.uri)
                    break
                end
            end
        end
    end

    -- 缓存命中
    if wafcdn_proxy_cache.time > 0 then
        local attr = lfs.attributes(wafcdn_proxy_cache.path)
        if attr == nil then
            wafcdn_proxy_cache.xCache = "MISS"
        else
            local age = ngx.time() - attr.modification
            if wafcdn_proxy_cache.time >= age then --缓存命中
                if ngx.var.request_method == "PURGE" then
                    local res, err = util.request("/@wafcdn/purge", {
                        query = {
                            site_id = ngx.var.wafcdn_site,
                            uri = wafcdn_proxy_cache.uri
                        },
                    })
                    if res == nil then
                        util.status(400, err)
                        return
                    end
                    util.status(200, res.body)
                    return
                end
                -- 处理header内容
                local header = util.cache_header(wafcdn_proxy_cache.path)
                if header == nil then
                    header = {}
                    header["X-Header"] = "NONE"
                end
                header["Cache-Control"] = "max-age=" .. wafcdn_proxy_cache.time
                header["Age"] = age
                header["X-Cache"] = "HIT"
                -- 处理相应
                ngx.var.wafcdn_header = util.header_merge(header)
                ngx.var.wafcdn_alias = util.json_encode({ file = wafcdn_proxy_cache.path })
                ngx.req.set_uri("/@alias", true) -- 请求终止
                return
            else                                 --缓存命中并过期 - 标记并重新缓存
                wafcdn_proxy_cache.xCache = "STALE"
            end
        end
        -- 走到这里肯定是要缓存的-增加缓存锁
        local attr = lfs.attributes(wafcdn_proxy_cache.path .. ".lock")
        if attr then
            local cacheWait = ngx.time() - attr.modification
            wafcdn_proxy_cache.xCache = "LOCK-" .. tostring(cacheWait)
            if cacheWait > 3600 then -- 超过一个小时还在缓存的文件
                os.remove(wafcdn_proxy_cache.path .. ".lock")
            end
            wafcdn_proxy_cache.time = 0
        end
    else
        wafcdn_proxy_cache.xCache = "BYPASS"
    end

    proxy.cache = wafcdn_proxy_cache
    ngx.var.wafcdn_proxy = util.json_encode(proxy)
    ngx.req.set_uri("/@proxy" .. ngx.var.uri, true)
end

-- 反向代理配置
-- !!! 必须使用rewrite 因为子请求会绕过access !!!
function WAFCDN_PROXY.rewrite()
    if ngx.var.wafcdn_proxy == "" then
        ngx.exec("/rewrite" .. ngx.var.uri)
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
            ip = ip,
            port = port,
            host = proxy.host,
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
    if ngx.ctx.wafcdn_proxy_cache.time > 0 then
        if util.contains(ngx.status, ngx.ctx.wafcdn_proxy_cache.status) then
            -- 创建缓存文件
            local file, err = io.open(ngx.ctx.wafcdn_proxy_cache.path .. ".lock", "wb")
            if not file then
                if util.mkdir(string.match(ngx.ctx.wafcdn_proxy_cache.path, "(.*)/")) then
                    file, err = io.open(ngx.ctx.wafcdn_proxy_cache.path .. ".lock", "wb")
                end
                if not file then
                    ngx.log(ngx.ERR, "cant open file:[", ngx.ctx.wafcdn_proxy_cache.path .. ".lock", "]", err)
                end
            end
            if file then -- 操作缓存
                local header = ngx.resp.get_headers(100, true)
                ngx.ctx.docache = {
                    header = header,
                    file = file,                            -- 文件句柄
                    path = ngx.ctx.wafcdn_proxy_cache.path, -- 文件路径
                    perfect = false,                        -- 是否完整
                    time = ngx.time()                       -- 缓存时间
                }
            end
        else
            ngx.ctx.wafcdn_proxy_cache.xCache = "RESP-" .. tostring(ngx.status)
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
        if ngx.ctx.docache.perfect then
            -- 写入文件。
            ngx.ctx.docache.file:close()
            os.rename(ngx.ctx.docache.path .. ".lock", ngx.ctx.docache.path)
            -- 将响应头写入 cache_path..".head" 文件
            local head, err = io.open(ngx.ctx.docache.path .. ".head", "wb")
            if head then
                head:write(util.json_encode(ngx.ctx.docache.header))
                head:close()
            else
                ngx.log(ngx.ERR, "cant open header file:[", ngx.ctx.wafcdn_proxy_cache.path .. ".head", "]", head_err)
            end


            -- 发送请求同步缓存状态
            local data = {
                site_id = tonumber(ngx.var.wafcdn_site),
                method = ngx.var.request_method,
                uri = ngx.ctx.wafcdn_proxy_cache.uri,
                -- header=ngx.ctx.docache.header,
                path = ngx.ctx.docache.path,
                time = ngx.ctx.docache.time
            }
            local handle = function()
                local res, err = util.request("/@wafcdn/cache", {
                    method = "PUT",
                    headers = { ["Content-Type"] = "application/json" },
                    body = util.json_encode(data)
                })
            end
            ngx.timer.at(0, handle) -- 是否批量提交缓存管理来提升性能。
        else
            os.remove(ngx.ctx.docache.path .. ".lock")
        end
    end
    -- 通用日志处理
    util.log()
end

return WAFCDN_PROXY
