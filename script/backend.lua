local init = require("init")
local lfs = require("lfs")
local http = require("http")
local json = require("cjson")

local docacheurl = init.socketapi .. "/socket/docache"

-- 递归创建缓存目录
---@param path string 要创建的文件路径
---@return boolean?
local function mkdir(path)
    local res, err = lfs.mkdir(path)
    if not res then
        if lfs.attributes(path, 'mode') == 'directory' then
            return true
        end
        local parent, count = string.gsub(path, "/[^/]+$", "")
        if count ~= 1 then
            ngx.log(ngx.ERR, "mkdir err:[", path, "]", err)
            return false
        end
        if mkdir(parent) then
            local lres, lerr = lfs.mkdir(path)
            if not lres then
                ngx.log(ngx.ERR, "mkdir err:[", path, "]", lerr)
            end
            return lres
        end
    end
    return res
end

local function getCacheData()
    return {
        path = ngx.ctx.docachefilepath,
        time = ngx.ctx.docachetime,
        identity = ngx.ctx.docacheidentity,
        uri = ngx.var.uri,
        size = tonumber(ngx.header["Content-Length"])
    }
end

local socketClient = function(_, data)
    local httpc = http.new()
    if not httpc then
        ngx.log(ngx.ERR, "http.new return nil")
        return nil
    end
    local current = os.time()
    local res, err = httpc:request_uri(docacheurl, {
        method = "POST",
        body = json.encode({
            SiteID = data.identity,
            Path = data.uri,
            File = data.path,
            Size = data.size,
            Accessed = current,
            Expried = current + (data.time * 60)
        }),
        headers = { ["Content-Type"] = "application/json" }
    })
    if not res then
        ngx.log(ngx.ERR, err)
        return nil
    end
    if res.status ~= 200 then
        ngx.log(ngx.ERR, "status:", res.status, "|body:", res.body)
    end
end

local downloadClient = function(premature, req, cacheMeta)
    local httpc = http.new()
    if not httpc then
        ngx.log(ngx.ERR, "http.new return nil")
        return nil
    end
    local res, reqerr = httpc:request_uri(req.url, req.params)
    if not res then
        ngx.log(ngx.ERR, "http.request_uri return nil err:", reqerr)
        return nil
    end
    if res.status == 200 then
        req.file:seek("set", 0)
        req.file:write(res.body)
        req.file:close()
        cacheMeta.size = tonumber(res.headers["Content-Length"])
        socketClient(premature, cacheMeta)
    else
        ngx.log(ngx.ERR, req.url, " cant download | status:", res.status)
        req.file:close()
        local success, err = os.remove(cacheMeta.path)
        if not success then
            ngx.log(ngx.ERR, "cant remove cache file ", err)
        end
    end
    httpc:close()
end

local function access()
    if ngx.ctx.backend ~= nil then
        ngx.var.backend_url = ngx.ctx.backend.url
        ngx.var.backend_host = ngx.ctx.backend.host
        for _, header in ipairs(ngx.ctx.backend.req_header) do
            if header.name and header.value then
                ngx.req.set_header(header.name, header.value)
            end
        end
    else
        init.setNotFoundDomain()
        return
    end
end

local function header()
    if ngx.ctx.docache then
        ngx.header["Server"] = init.serverFlagDocache
        if ngx.status == 200 then
            local file, err = io.open(ngx.ctx.docachefilepath, "wb")
            if not file then
                if mkdir(ngx.ctx.docachefilepath:match("(.*)/")) then
                    file, err = io.open(ngx.ctx.docachefilepath, "wb")
                end
                if not file then
                    ngx.log(ngx.ERR, "cant open file:[", ngx.ctx.docachefilepath, "]", err)
                    ngx.ctx.docache = false
                    return
                end
            end
            ngx.ctx.docachefile = file
        end
    else
        ngx.header["Server"] = init.serverFlagBackend
    end
end

local function body()
    if ngx.ctx.docache and ngx.ctx.docachefile then
        ngx.ctx.docachefile:write(ngx.arg[1])
        if ngx.arg[2] == true then
            ngx.ctx.docachefinish = true
        end
    end
end

local function log()
    if ngx.ctx.docache and ngx.ctx.docachefile then
        if ngx.ctx.docachefinish then
            ngx.ctx.docachefile:close()
            local ok, err = ngx.timer.at(0, socketClient, getCacheData())
            if not ok then
                ngx.log(ngx.ERR, "cont create ngx.timer err:", err)
            end
        else
            -- 重新下载。
            local downloadInfo = {
                file = ngx.ctx.docachefile,
                url = ngx.var.backend_url .. ngx.var.request_uri, --请求的网址
                params = {
                    method = ngx.req.get_method(),
                    headers = ngx.req.get_headers(),
                    body = ngx.req.get_body_data()
                }
            }
            local ok, err = ngx.timer.at(0, downloadClient, downloadInfo, getCacheData())
            if not ok then
                ngx.log(ngx.ERR, "cont create ngx.timer err:", err)
                ngx.ctx.docachefile:close()
                local success, rmerr = os.remove(ngx.ctx.docachefilepath)
                if not success then
                    ngx.log(ngx.ERR, "cant remove cache file:[", ngx.ctx.docachefilepath, "]", rmerr)
                end
            end
        end
    end
end

return {
    access = access,
    header = header,
    body = body,
    log = log,
}
