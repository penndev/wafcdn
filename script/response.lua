-- 定义统一返回状态的内容
local ngx = require("ngx")

local response = {}

function response.status(status, message)
    -- 配置域名未找到
    -- ngx.status = 404
    ngx.say(status .. "->" .. message)
    ngx.exit(status)
end


return response