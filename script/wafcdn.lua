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
    -- 获取后台配置
    local res, err = util.request( "/@wafcdn/domain", {args={host=host}})
    if res == nil then
        response.status(404, "Not Found")
        return
    end

    -- !IP黑名单

    -- rate单链接限速，并发请求限速。
    if res.body.security.limit.status == true then
        local limit = res.body.security.limit
        local qps = limit.queries / limit.seconds
        local allow = filter.limit(limit.rate, qps, limit.queries)
        if not allow then
            response.status(429, "Too Many Requests")
            return
        end
    end
    -- !IP区域控制

    -- 接口验签
    if res.body.security.sign.status == true then
        local sign = res.body.security.sign
        local allow, err = filter.sign(sign.method, sign.key, sign.timeargs, sign.signargs, sign.expires)
        if not allow then
            response.status(403, "Forbidden " .. err)
            return
        end
    end

    -- !JS人机校验
    --  ...

    ngx.ctx.domain = res.body
end

function WAFCDN.access()
    -- 访问静态文件
    -- 访问反向代理
    ngx.say(util.json_encode(ngx.ctx.domain) )
    ngx.say(os.date("!%Y-%m-%d %H:%M:%S"))
    -- 
end

function WAFCDN.log()
    -- 获取客户端 IP 地址
    local ip = ngx.var.remote_addr
    local request_method = ngx.var.request_method
    local request_uri = ngx.var.request_uri
    local status = ngx.var.status
    local time = ngx.localtime()
    ngx.log(ngx.ERR, "Time: ", time, " | IP: ", ip, " | Method: ", request_method, " | URI: ", request_uri, " | Status: ", status)
end

return WAFCDN
