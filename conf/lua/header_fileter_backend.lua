if ngx.ctx.docache then
    if ngx.status == 200 then 
        local filepath = ngx.ctx.cache_path:match("(.*/)")
        if require("common").mkdir(filepath) then -- 创建目录失败
            local file, err = io.open(ngx.ctx.cache_path, "w")
            if err then 
                ngx.log(ngx.ERR, err)
            end
            ngx.ctx.docachefile = file
        else
            ngx.ctx.docache = false
        end
    end
end

if ngx.ctx.docache then
    ngx.header["Server"] = "cnd/docache"
else
    ngx.header["Server"] = "cnd/back"
end