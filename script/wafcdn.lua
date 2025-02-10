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
        response.status(404, "02")
        return
    end

    -- !IP黑名单

    -- rate单链接限速，并发请求限速。
    local qps = res.body.limit.queries / res.body.limit.seconds
    local allow = filter.limit(res.body.limit.rate, qps, res.body.limit.queries)
    if not allow then 
        response.status(419, "03")
        return
    end
    
    -- !IP区域控制

    -- 接口验签
    if res.body.security.status == true then 
        filter.sign(res.body.security.method, res.body.security.timeargs, res.body.security.signargs)
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
    local str = util.hmac('md5', 'wafcdn', '123456')
    ngx.say(str)
end

return WAFCDN
