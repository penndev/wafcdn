-- 设置回源请求 动态处理回源参数。
if ngx.ctx.backend ~= nil then
    ngx.var.backend_url = ngx.ctx.backend.url
    ngx.var.backend_host = ngx.ctx.backend.host
    for _,header in ipairs(ngx.ctx.backend.req_header) do
        if header.name and header.value then
            ngx.req.set_header(header.name, header.value)
        end
    end
else
    ngx.status = 403
    ngx.say("cant find the backend")
    return ngx.exit(403)
end