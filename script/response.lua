-- 定义统一返回状态的内容
local ngx = require("ngx")

local response = {}

function response.status400()
    -- 所有非标准请求错误
    ngx.status = 400
    ngx.say("400")
    ngx.exit(404)
end


function response.status403()
    -- 配置域名未找到
    -- ngx.status = 404
    ngx.say("403")
    ngx.exit(403)
end

function response.status404()
    -- 配置域名未找到
    ngx.status = 404
    ngx.say("404")
    ngx.exit(404)
end

function response.status419()
    -- 配置域名未找到
    ngx.status = 419
    ngx.say("419")
    ngx.exit(419)
end

function response.status424()
    -- 服务器进行请求鉴权失败的响应
    ngx.status = 424
    ngx.say("424")
    ngx.exit(424)
end

return response