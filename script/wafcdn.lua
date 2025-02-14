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
    
    -- 从其他地方重定向过来的-进行/rewrite修复
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
    else 
        response.status(403, "SiteType")
        return
    end
end

-- 静态文件目录访问
local static_start = string.len("/@static") + 1
function WAFCDN.static_access()
    -- 用户直接输入访问 /@static
    if ngx.var.wafcdn_static == "" then 
        ngx.exec("/rewrite"..ngx.var.uri)
        return
    end
    -- 修复移除添加路由的
    ngx.req.set_uri(string.sub(ngx.var.uri, static_start), false)
    local static = util.json_decode(ngx.var.wafcdn_static)
    -- 静态文件目录
    ngx.var.static_root = static.root
    return
end

-- 静态文件目录访问
local proxy_start = string.len("/@proxy") + 1
function WAFCDN.proxy_access()
    if ngx.var.wafcdn_proxy == "" then 
        ngx.exec("/rewrite"..ngx.var.uri)
        return
    end
    
    ngx.req.set_uri(string.sub(ngx.var.uri, proxy_start), false)
    local proxy = util.json_decode(ngx.var.wafcdn_proxy)

    ngx.say(util.json_encode(proxy))
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
