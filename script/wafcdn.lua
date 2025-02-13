local ngx = require("ngx")
local response = require("response")
local util = require("util")
local filter = require("filter")

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
        response.status(404, "Not Found")
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


    ngx.var.wafcdn_site = res.body.site

    -- 
    -- 路由
    -- 
    if res.body.type == "static" then
        ngx.var.wafcdn_static = util.json_encode(res.body.static)
        ngx.req.set_uri("/@static" .. ngx.var.request_uri, true)
        return
    elseif res.body.type == "proxy" then
        ngx.var.wafcdn_proxy = util.json_encode(res.body.proxy)
        ngx.req.set_uri("/@proxy" .. ngx.var.request_uri, true)
        return
    else 
        response.status(403, "SiteType")
        return
    end
end


function WAFCDN.access_static()
    ngx.log(ngx.ERR, "penndev->", ngx.var.wafcdn_site, "<>")
    return
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
