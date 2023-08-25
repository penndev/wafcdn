-- 设置回源请求
if ngx.ctx.back ~= nil then
    ngx.var.backend_url = ngx.ctx.back.url
    ngx.var.backend_host = ngx.ctx.back.host
    for _,header in ipairs(ngx.ctx.back.header) do
        ngx.req.set_header(header.header_name, header.header_value)
    end
else
    ngx.status = 403
    ngx.say("Error: Cant get backend config info!")
    return ngx.exit(403)
end
