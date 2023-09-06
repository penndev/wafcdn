local common = require("common")

if ngx.ctx.docache and ngx.ctx.docachefile then
    local cacheData = {
        url = ngx.var.domain_url .. "/cached",
        path = ngx.ctx.docachefilepath,
        time = ngx.ctx.docachetime,
        identity = ngx.ctx.docacheidentity,
        uri = ngx.var.uri,
        size = 0
    }
    if ngx.ctx.docachefinish then
        -- 获取相应内容的大小。cacheData.size = 
        ngx.ctx.docachefile:close()
        local ok, err = ngx.timer.at(0, common.setcache, cacheData)
        if not ok then
            ngx.log(ngx.ERR, "backend_url cont create ngx.timer err:", err)
        end
    else
        -- 重新下载文件并
        local downData = {
            file = ngx.ctx.docachefile,
            url = ngx.var.backend_url ..  ngx.var.request_uri, --请求的网址
            params = { keepalive_timeout = 60000, keepalive_pool = 10, method = ngx.req.get_method(), headers = ngx.req.get_headers(), body = ngx.req.get_body_data() }
        }
        ngx.log(ngx.ERR, "重新下载文件", downData.url)
        local ok, err = ngx.timer.at( 0, common.redownload,  downData,  cacheData )
        if not ok then
            ngx.log(ngx.ERR, "redownload() cont create ngx.timer err:", err)
            ngx.ctx.docachefile:close()
            os.remove(ngx.ctx.docachefilepath)
        end
    end
end
