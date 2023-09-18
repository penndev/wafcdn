local json = require("cjson")

local args, err = ngx.req.get_uri_args()
if err then
    ngx.log(ngx.ERR, "ngx.req.get_uri_args err:", err)
    return ngx.exit(403)
end

ngx.var.cache_file = args.cache_file

ngx.ctx.backend = {resp_header = json.decode(args.resp_header)}
