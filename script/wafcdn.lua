local ngx = require("ngx")
local response = require("response")
local util = require("util")
local filter = require("filter")

local WAFCDN = {}

function WAFCDN.rewrite()
    local host = ngx.var.host
    if not host then
        response.status400()
        return
    end
    -- 获取后台配置
    local res, err = util.request( "/@wafcdn/domain", {args={host=host}})
    if res == nil then
        response.status404()
        return
    end

    -- !IP黑名单

    -- rate单链接限速，并发请求限速。
    local qps = res.body.limit.queries / res.body.limit.seconds
    local allow = filter.limit(res.body.limit.rate, qps, res.body.limit.queries)
    if not allow then 
        response.status419()
        return
    end
    
    -- !IP区域控制

    -- !接口验签

    -- !JS人机校验
    ngx.ctx.domain = res.body
end

function WAFCDN.access()
    -- 访问静态文件
    
    -- 访问反向代理
    ngx.say(util.json_encode(ngx.ctx.domain) )
end

return WAFCDN
