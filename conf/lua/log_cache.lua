local common = require("common")

local ok, err = ngx.timer.at(0, common.upcache,  ngx.var.cache_file,  os.time())
if not ok then
    ngx.log(ngx.ERR, "upcache() cont create ngx.timer err:", err)
end