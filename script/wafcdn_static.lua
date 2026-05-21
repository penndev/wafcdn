local ngx = require("ngx")
local util = require("util")

local WAFCDN_STATIC = {}

function WAFCDN_STATIC.ROUTE(static)
    local root = static.root
    if root == nil or root == "" then
        util.status(500, "STATIC_ROOT_NOT_SET")
        return
    end
    if string.find(ngx.var.uri, "..", 1, true) then
        util.status(403, "FORBIDDEN_PATH")
        return
    end
    ngx.var.wafcdn_static = string.gsub(root, "/+$", "")
    ngx.req.set_uri("/@static" .. ngx.var.uri, true)
end

function WAFCDN_STATIC.rewrite()
    if ngx.var.wafcdn_static == "" then
        ngx.exec("/rewrite" .. ngx.var.uri)
        return
    end
    ngx.req.set_uri(string.sub(ngx.var.uri, 9), false)
    ngx.var.wafcdn_static_root = ngx.var.wafcdn_static
end

function WAFCDN_STATIC.header_filter()
    util.header_response()
end

function WAFCDN_STATIC.log()
    util.log()
end

return WAFCDN_STATIC
