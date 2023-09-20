local common = require("common")
if ngx.ctx.docache then
    ngx.header["Server"] = "cnd#docache"
else
    ngx.header["Server"] = "cnd#back"
end

if ngx.ctx.docache then
    if ngx.status == 200 then
        local file, err = io.open(ngx.ctx.docachefilepath, "wb")
        if err then
            local directory = string.match(ngx.ctx.docachefilepath, "(.*)/")
            if common.mkdir(directory) then
                file, err = io.open(ngx.ctx.docachefilepath, "wb")
            end
            if err then
                ngx.log(ngx.ERR, err, "|", ngx.ctx.docachefilepath, "|")
                file = nil
            end
        end
        ngx.ctx.docachefile = file
    end
end