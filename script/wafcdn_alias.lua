local ngx = require("ngx")
local util = require("util")

local WAFCDN_ALIAS = {}

-- 静态文件目录访问
function WAFCDN_ALIAS.rewrite()
    -- 用户直接输入访问 /@static
    if ngx.var.wafcdn_alias == "" then
        ngx.exec("/rewrite"..ngx.var.uri)
        return
    end

    local alias, _ = util.json_decode(ngx.var.wafcdn_alias)
    if alias == nil then
        util.status(500, "INTERNAL_ALIAS_JSON_FAIL")
        return
    end
    -- 静态文件
    ngx.var.wafcdn_alias_file = alias.file
end


function WAFCDN_ALIAS.header_filter()
    util.header_response()
end

function WAFCDN_ALIAS.log()
    util.log()
end

return WAFCDN_ALIAS