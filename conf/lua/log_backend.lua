local common = require("common")

if ngx.ctx.docache and ngx.ctx.docachefile then
    local cacheData = {
        path = ngx.ctx.docachefilepath,
        time = ngx.ctx.docachetime,
        identity = ngx.ctx.docacheidentity,
        uri = ngx.var.uri,
        size = 0
    }
    if ngx.ctx.docachefinish then
        -- 获取相应内容的大小。cacheData.size = 
        ngx.ctx.docachefile:close()
        cacheData.size = tonumber(ngx.header["Content-Length"])
        local ok, err = ngx.timer.at(0, common.docache, cacheData)
        if not ok then
            ngx.log(ngx.ERR, "backend_url cont create ngx.timer err:", err)
        end
    else
        -- 重新下载文件
        local req = {
            file = ngx.ctx.docachefile,
            url = ngx.var.backend_url ..  ngx.var.request_uri, --请求的网址
            params = { keepalive_timeout = 60000, keepalive_pool = 10, method = ngx.req.get_method(), headers = ngx.req.get_headers(), body = ngx.req.get_body_data() }
        }
        local ok, err = ngx.timer.at(0, common.redownload,  req,  cacheData )
        if not ok then
            ngx.log(ngx.ERR, "redownload() cont create ngx.timer err:", err)
            ngx.ctx.docachefile:close()
            local success, err = os.remove(ngx.ctx.docachefilepath)
            if not success then
                ngx.log(ngx.ERR, "cant remove cache file ", err)
            end
        end
    end
end
