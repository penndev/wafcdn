if ngx.ctx.docache then
    if ngx.status == 200 then 
        local filepath = ngx.ctx.docachefilepath:match("(.*/)")
        if require("common").mkdir(filepath) then -- 创建目录失败
            local file, err = io.open(ngx.ctx.docachefilepath, "w")
            if err then 
                ngx.log(ngx.ERR, err)
                ngx.ctx.docache = false
                return
            end
            ngx.ctx.docachefile = file
        else
            ngx.ctx.docache = false
        end
    end
end

if ngx.ctx.docache then
    ngx.header["Server"] = "cnd#docache"
else
    ngx.header["Server"] = "cnd#back"
end

-- 处理响应头 ngx.ctx.backend.rheader