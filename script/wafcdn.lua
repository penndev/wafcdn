local ngx = require("ngx")
local ssl = require("ngx.ssl")
local util = require("module.util")
local filter = require("module.filter")
local proxy = require("wafcdn_proxy")


local WAFCDN = {}

function WAFCDN.ssl()
    local hostname, err = ssl.server_name()
    if not hostname then
        ngx.log(ngx.INFO, "failed to get server_name certificates:", err)
        return ngx.exit(ngx.ERROR)
    end

    local cleared, err = ssl.clear_certs()
    if not cleared then
        ngx.log(ngx.ERR, "failed to clear existing (fallback) certificates:", err)
        return ngx.exit(ngx.ERROR)
    end

    local domain, err = util.request("/@wafcdn/ssl", {query={ host=hostname }, cache=10})
    if not domain then
        ngx.log(ngx.INFO, "failed to get api domain:", hostname, " ",err)
        return ngx.exit(ngx.ERROR)
    end
    -- 设置公钥
    local cert, err = ssl.cert_pem_to_der(domain.body.publickey)
    if not cert then
        ngx.log(ngx.ERR, "failed to convert certificate chain from PEM to DER: ", err)
        return ngx.exit(ngx.ERROR)
    end

    local public, err = ssl.set_der_cert(cert)
    if not public then
        ngx.log(ngx.ERR, "failed to set DER cert:", err)
        return ngx.exit(ngx.ERROR)
    end

    -- 设置私钥
    local key, err = ssl.priv_key_pem_to_der(domain.body.privatekey)
    if not key then
        ngx.log(ngx.ERR, "failed to convert private key from PEM to DER:", err)
        return ngx.exit(ngx.ERROR)
    end
    local private, err = ssl.set_der_priv_key(key)
    if not private then
        ngx.log(ngx.ERR, "failed to set DER private key:", err)
        return ngx.exit(ngx.ERROR)
    end
end


function WAFCDN.rewrite()
    -- 获取域名
    local host = ngx.var.host
    if not host then
        util.status(400, "CANT_GET_HOST")
        return
    end

    -- 获取域名后台配置
    local res, err = util.request("/@wafcdn/domain", {query={ host=host }, cache=3})
    if res == nil then
        util.status(404, err)
        return
    end

    -- http请求强制https
    if res.sslforce and not ngx.var.https then
        ngx.redirect("https://" .. host .. ngx.var.request_uri, 301)
        return
    end

    -- -- -- -- -- -- -- -- --
    -- !IP黑名单处理
    -- !IP区域控制
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
        local allow, err = filter.sign(sign.method, sign.key, sign.expireargs, sign.signargs)
        if not allow then
            util.status(403, "Forbidden " .. err)
            return
        end
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
    -- # 设置全局变量
    ngx.var.wafcdn_site = body.site -- 站点ID
    ngx.var.wafcdn_header = util.json_encode(body.header) -- 用户返回头
    if body.type == "proxy" then
        proxy.ROUTE(body.proxy)
        return
    elseif body.type == "alisa" then
        -- 固定缓存的文件根据请求地址来计算静态文件是哪个。
        -- ngx.var.wafcdn_static = util.json_encode({file = body.file})
        -- ngx.req.set_uri("/@alisa", true)
        return
    else
        util.status(403, "INTERNAL_FAILED_SITE_TYPE")
        return
    end
end

return WAFCDN
