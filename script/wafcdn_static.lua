local ngx = require("ngx")
local util = require("module.util")

local WAFCDN_STATIC = {}

-- 静态文件目录访问
function WAFCDN_STATIC.rewrite()
    -- 用户直接输入访问 /@static
    if ngx.var.wafcdn_static == "" then
        ngx.exec("/rewrite"..ngx.var.uri)
        return
    end
    -- 修复移除添加路由的
    -- local static_start = string.len("/@static") + 1
    ngx.req.set_uri(string.sub(ngx.var.uri, 9), false)
    local static = util.json_decode(ngx.var.wafcdn_static)
    -- 静态文件目录
    ngx.var.wafcdn_static_root = static.root
end

return WAFCDN_STATIC