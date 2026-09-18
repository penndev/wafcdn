local ngx = require("ngx")
local util = require("util")

local mime = {
    html = "text/html; charset=utf-8",
    htm = "text/html; charset=utf-8",
    css = "text/css; charset=utf-8",
    js = "application/javascript; charset=utf-8",
    json = "application/json",
    png = "image/png",
    jpg = "image/jpeg",
    jpeg = "image/jpeg",
    gif = "image/gif",
    svg = "image/svg+xml",
    ico = "image/x-icon",
    webp = "image/webp",
    txt = "text/plain; charset=utf-8",
    xml = "application/xml",
    pdf = "application/pdf",
    woff = "font/woff",
    woff2 = "font/woff2",
    ttf = "font/ttf",
    wasm = "application/wasm",
}

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
    -- /@alias 没有扩展名，nginx 会先打成 text/plain，这里按真实文件覆盖
    local file = ngx.var.wafcdn_alias_file or ""
    local ext = string.match(string.lower(file), "%.([^.]+)$")
    if ext and mime[ext] then
        ngx.header["Content-Type"] = mime[ext]
    end
end

function WAFCDN_ALIAS.log()
    util.log()
end

return WAFCDN_ALIAS