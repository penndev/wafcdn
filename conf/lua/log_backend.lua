local common = require("common")

local function handleDownload(premature, file,filepath, uri, params)
    file:seek("set")
    local httpc = require("http").new()
    local res, err = httpc:request_uri(uri, params)
    file:write(res.body)
    httpc:close()
    file:close()
    common.setcache(filepath)
end

if ngx.ctx.docache and ngx.ctx.docachefile then
    -- local cacheData = {
    --     site = 1,
    --     url = ngx.var.request_uri,
    --     path = ngx.ctx.cache_path, 
    --     size = 0, 
    --     expired
    -- }

    if ngx.ctx.docachefinish then
        ngx.ctx.docachefile:close()
        common.setcache(ngx.ctx.cache_path)
    else
        local ok, err = ngx.timer.at(
            0, 
            handleDownload, 
            ngx.ctx.docachefile,
            ngx.ctx.cache_path,
            ngx.var.backend_url ..  ngx.var.request_uri,
            {
                method = ngx.req.get_method(),
                headers = ngx.req.get_headers(),
                body = ngx.req.get_body_data(),
                keepalive_timeout = 60000,
                keepalive_pool = 10
            }
        )
        if not ok then
            ngx.log(ngx.ERR, "无法创建定时器：", err)
            ngx.ctx.docachefile:close()
            os.remove(ngx.ctx.cache_path)
        end
    end
end
