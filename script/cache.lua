local init = require("init")
local http = require("http")
local json = require("json")

local upcacheurl = init.socketapi .. "/socket/upcache"

local socketClient = function(premature, data)
    local httpc = http.new()
    if not httpc then
        ngx.log(ngx.ERR, "http.new return nil")
        return nil
    end
    local res, err = httpc:request_uri(upcacheurl, {
        method = "POST",
        body = json.encode(data),
        headers = {
            ["Content-Type"] = "application/json",
        }
    })
    if not res then
        ngx.log(ngx.ERR, err)
        return nil
    end
    if res.status ~= 200 then
        ngx.log(ngx.ERR, "status:", res.status, "|body:", res.body)
    end
end

local function access()
    local args, err = ngx.req.get_uri_args()
    if err then
        ngx.log(ngx.ERR, "ngx.req.get_uri_args err:", err)
        return ngx.exit(403)
    end
    ngx.var.cache_file = args.cache_file
end

local function header()
    if ngx.ctx.backend.resp_header then
        for _, headeritem in ipairs(ngx.ctx.backend.resp_header) do
            if headeritem.name and headeritem.value then
                ngx.header[headeritem.name] = headeritem.value
            end
        end
    end
    ngx.header["Server"] = init.serverFlagCache
end


local function log()
    local ok, err = ngx.timer.at(0, socketClient, { File = ngx.var.cache_file, Accessed = os.time() })
    if not ok then
        ngx.log(ngx.ERR, "upcache() cont create ngx.timer err:", err)
    end
end

return {
    access = access,
    header = header,
    log = log,
}
