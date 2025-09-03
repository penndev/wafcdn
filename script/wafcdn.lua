local ngx = require("ngx")
local ssl = require("ngx.ssl")
local util = require("util")
local filter = require("filter")
local proxy = require("wafcdn_proxy")

local WAFCDN = {}

function WAFCDN.ssl()
    local hostname, err = ssl.server_name()
    if not hostname then
        -- ngx.log(ngx.INFO, "failed to get server_name certificates:", err)
        return ngx.exit(ngx.ERROR)
    end

    local cleared, err = ssl.clear_certs()
    if not cleared then
        -- ngx.log(ngx.ERR, "failed to clear existing (fallback) certificates:", err)
        return ngx.exit(ngx.ERROR)
    end

    local domain, err = util.request("/@wafcdn/ssl", {
        query = {host = hostname},
        cache = 10
    })
    if not domain then
        -- ngx.log(ngx.INFO, "failed to get api domain:", hostname, " ", err)
        return ngx.exit(ngx.ERROR)
    end
    -- 设置公钥
    local cert, err = ssl.cert_pem_to_der(domain.body.publicKey)
    if not cert then
        -- ngx.log(ngx.ERR, "failed to convert certificate chain from PEM to DER: ", err)
        return ngx.exit(ngx.ERROR)
    end

    local public, err = ssl.set_der_cert(cert)
    if not public then
        -- ngx.log(ngx.ERR, "failed to set DER cert:", err)
        return ngx.exit(ngx.ERROR)
    end

    -- 设置私钥
    local key, err = ssl.priv_key_pem_to_der(domain.body.privateKey)
    if not key then
        -- ngx.log(ngx.ERR, "failed to convert private key from PEM to DER:", err)
        return ngx.exit(ngx.ERROR)
    end
    local private, err = ssl.set_der_priv_key(key)
    if not private then
        -- ngx.log(ngx.ERR, "failed to set DER private key:", err)
        return ngx.exit(ngx.ERROR)
    end
end

function WAFCDN.acme()
    if ngx.var.https ~= "" then
        util.status(404, "ACME_NOT_HTTPS")
        return
    end

    local token = ngx.var.uri:sub(#"/.well-known/acme-challenge/" + 1)
    if token == nil or token == "" then
        util.status(404, "ACME_NOT_FOUND")
        return
    end

    local res, err = util.request("/@wafcdn/acme", {query = { token = token },})
    if res == nil then
        util.status(404, err)
        return
    end
    ngx.say(res.body)
    return ngx.exit(res.status)
end

function WAFCDN.rewrite()
    -- 获取域名
    local host = ngx.var.host
    if not host then
        util.status(400, "CANT_GET_HOST")
        return
    end

    -- 获取域名后台配置
    local res, err = util.request("/@wafcdn/domain", {
        query = {
            host = host
        },
        cache = 3
    })

    if res == nil then
        util.status(404, err)
        return
    end

    if  tonumber(res.body.site) == nil then
        util.status(404, "SITE_NOT_SET")
        return
    end

    -- 设置全局变量
    ngx.var.wafcdn_site = res.body.site -- 站点ID
    ngx.var.wafcdn_header = util.json_encode(res.body.header)

    -- -- -- -- -- -- -- -- --
    -- !IP黑名单处理
    -- !IP区域控制
    -- -- -- -- -- -- -- -- --
    local ip = res.body.security.ip
    if ip.status == true then
        local _, ipErr = util.request("/@wafcdn/ip-verify", {
            query = {
                site = ngx.var.wafcdn_site,
                ip = ngx.var.remote_addr
            },
            cache = 3
        })
        if ipErr ~= nil then
            util.status(403, ipErr)
            return
        end
    end

    -- -- -- -- -- -- -- -- --
    -- !User-Agent设备控制列表
    -- !Referrer引用控制
    -- -- -- -- -- -- -- -- --

    -- rate单链接限速，并发请求限速。
    local limit = res.body.security.limit
    if limit.status == true then
        local allow = filter.limit(limit.rate, limit.queries / limit.seconds, limit.queries)
        if not allow then
            util.status(429, "Too Many Requests")
            return
        end
    end

    -- 接口验签
    local sign = res.body.security.sign
    if sign.status == true then
        local allow, allowErr = filter.sign(sign.method, sign.key, sign.expire_args, sign.sign_args)
        if not allow then
            util.status(403, "Forbidden " .. allowErr)
            return
        end
    end

    -- 跨域处理
    local cors = res.body.security.cors
    if cors.status == true then
        local corsHeader = {}
        if cors.origin ~= "" then
            corsHeader["Access-Control-Allow-Origin"] = cors.origin
        end
        if cors.method ~= "" then
            corsHeader["Access-Control-Allow-Methods"] = cors.method
        end
        if cors.header ~= "" then
            corsHeader["Access-Control-Allow-Headers"] = cors.header
        end
        if cors.credentials ~= "" then
            corsHeader["Access-Control-Allow-Credentials"] = cors.credentials
        end
        if cors.age > 0 then
            corsHeader["Access-Control-Max-Age"] = cors.age
        end
        ngx.var.wafcdn_header = util.header_merge(corsHeader)
        if ngx.req.get_method() == "OPTIONS" then
            return ngx.exit(204)
        end
    end

    -- http请求强制https
    if res.body.sslForce == true and ngx.var.https == "" then
        ngx.redirect("https://" .. host .. ngx.var.request_uri, 301)
        return
    end

    -- # 修正请求地址
    -- 从其他地方重定向过来的 会在原本请求url中添加 /rewrite
    -- 但是ngx.var.request_uri未改变，
    -- 所以可以对比开头来判断是否是重定向过来的
    if string.sub(ngx.var.uri, 0, 9) == "/rewrite/" then
        if string.sub(ngx.var.request_uri, 0, 9) ~= "/rewrite/" then
            ngx.req.set_uri(string.sub(ngx.var.uri, 9), false)
        end
    end

    WAFCDN.ROUTE(res.body)
end

-- 处理用户设置的header头
function WAFCDN.header_filter()
    util.header_response()
end

-- 路由
-- @param table data
-- @return void
function WAFCDN.ROUTE(body)
    -- 文件请求类型
    -- @type
    --  - proxy反向代理方式
    --  - alisa静态文件访问 -待实现
    --  - fast_cgi  -待实现
    --  - tcp_proxy -待实现
    if body.type == "proxy" then
        proxy.ROUTE(body.proxy)
        return
        -- elseif body.type == "alisa" then
        --     -- 固定缓存的文件根据请求地址来计算静态文件是哪个。
        --     -- ngx.var.wafcdn_static = util.json_encode({file = body.file})
        --     -- ngx.req.set_uri("/@alisa", true)
        --     return
    else
        util.status(403, "INTERNAL_FAILED_SITE_TYPE")
        return
    end
end

function WAFCDN.log()
    util.log()
end

return WAFCDN
