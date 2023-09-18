if ngx.ctx.backend.resp_header then
    for _,header in ipairs(ngx.ctx.backend.resp_header) do
        if header.name and header.value then
            ngx.header[header.name] =  header.value
        end
    end
end
ngx.header["Server"] = "wafcnd#cache"