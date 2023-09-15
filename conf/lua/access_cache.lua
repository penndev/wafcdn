-- local common = require("common")
-- ngx.var.cache_dir = common.getenv("CACHE_DIR")

-- print(ngx.ctx.cachefilepath)

local args, err = ngx.req.get_uri_args()
if err then
    ngx.log(ngx.ERR, "ngx.req.get_uri_args err:", err)
    return ngx.exit(403)
end

ngx.var.cache_file = args.cache_file