if ngx.ctx.docache then
    if ngx.status == 200 then 
        local file, err = io.open(ngx.ctx.cache_path, "w")
        if err then 
            ngx.log(ngx.ERR, err)
        end
        ngx.ctx.docachefile = file
    end
end

ngx.header["Server"] = "cnd/back"
