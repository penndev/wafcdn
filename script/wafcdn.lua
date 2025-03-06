local ngx = require("ngx")
local util = require("module.util")
local filter = require("module.filter")

local WAFCDN = {}

function WAFCDN.status(status, message)
    ngx.status = status
    ngx.say(status .. "->" .. message)
    ngx.exit(status)
end

function WAFCDN.rewrite()
    local host = ngx.var.host
    if not host then
        WAFCDN.status(400, "01")
        return
    end

    -- 获取后台配置
    local res, err = util.request("/@wafcdn/domain", {
        args={ host=ngx.var.host },
    })
    if res == nil then
        WAFCDN.status(406, "Domain Not Found".. err)
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
            WAFCDN.status(429, "Too Many Requests")
            return
        end
    end

    -- 接口验签
    local sign = res.body.security.sign
    if sign.status == true then
        local allow, err = filter.sign(sign.method, sign.key, sign.expireargs, sign.signargs)
        if not allow then
            WAFCDN.status(403, "Forbidden " .. string(err))
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
    ngx.var.wafcdn_header = util.json_encode(res.body.header)
    --
    -- 路由
    --
    if res.body.type == "static" then
        ngx.var.wafcdn_static = util.json_encode(res.body.static)
        ngx.req.set_uri("/@static" .. ngx.var.uri, true)
        return
    elseif res.body.type == "proxy" then
        ngx.var.wafcdn_proxy = util.json_encode(res.body.proxy)
        ngx.req.set_uri("/@proxy" .. ngx.var.uri, true)
        return
    else
        WAFCDN.status(403, "SiteType")
        return
    end
end

-- 处理用户设置的header头
function WAFCDN.header_filter()
    if ngx.var.wafcdn_header == "" then
        return
    end
    local header = util.json_decode(ngx.var.wafcdn_header)
    for key, val in pairs(header) do
        ngx.header[key] = val
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
