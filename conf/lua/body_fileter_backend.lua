if ngx.ctx.docache and ngx.ctx.docachefile then
    ngx.ctx.docachefile:write(ngx.arg[1])
    if ngx.arg[2] == true then
        ngx.ctx.docachefinish = true
    end
end
