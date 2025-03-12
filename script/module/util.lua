local ngx = require("ngx")
local cjson = require("cjson")
local lfs = require("module.lfs")
local http = require("resty.http")
local openssl_hmac = require("resty.openssl.hmac")

cjson.encode_escape_forward_slash(false)

local util = {}

-- json编码器
-- @param any
-- @return result, error
    -- string
    -- nil, string
function util.json_encode(data)
    local ok, result = pcall(cjson.encode, data)
    if ok then
        return result
    else
        return nil, "JSON encode error: " .. tostring(result)
    end
end

-- json解码器
-- @param string
-- @return result, error
    -- table
    -- nil, string
function util.json_decode(data)
    local ok, result = pcall(cjson.decode, data)
    if ok then
        return result
    else
        return nil, "JSON decode error: " .. tostring(result)
    end
end


-- 发起与主控网络请求
-- https://github.com/ledgetech/lua-resty-http?tab=readme-ov-file#request_uri
-- @param uri 请求网址
-- @param table 请求描述
-- @return table 返回体
function util.request(uri, opt)

    local timeout = 3000
    local api = "http://172.21.16.1:8000"

    local url = api .. uri
    local msg = "WAFCDN_INTERNAL_HTTP_FAIL"

    local client, err = http.new()
    if not client then
        ngx.log(ngx.ERR, "Failed to create http client: ", err)
        return nil, msg
    end
    client:set_timeout(timeout) -- 3秒超时

    local res, err = client:request_uri(url, opt)
    if not res then
        ngx.log(ngx.ERR, "HTTP request failed: ", err)
        return nil, msg
    end

    if res.status ~= 200 then
        return nil, 'INTERNAL_HTTP_STATUS_' .. res.status
    end
    if not res.body then
        return nil, 'INTERNAL_HTTP_BODY_FAIL'
    end
    local body, err = util.json_decode(res.body)
    if not body then
        return nil, 'INTERNAL_HTTP_BODY_JSON_FAIL'
    end
    res.body = body
    return res
end

-- base64 url编码
function util.base64_url_encode(char)
    return ngx.encode_base64(char):gsub("+", "-"):gsub("/", "_"):gsub("=", "")
end

-- hmac算法
-- @param method hmac算法
-- @param key 加密的key
-- @param message 加密的消息
-- @return hex string 结果
function util.hmac(method, key, message)
    local hmac_method = openssl_hmac.new(key, method)
    hmac_method:update(message)
    return hmac_method:final()
end

-- 判断数组是否包含某个值`
function util.contains(value, array)
    for _, v in ipairs(array) do
        if v == value then
            return true
        end
    end
    return false
end

-- 递归创建缓存目录
---@param path string 要创建的文件路径
---@return boolean?
function util.mkdir(path)
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
        if util.mkdir(parent) then
            local lres, lerr = lfs.mkdir(path)
            if not lres then
                ngx.log(ngx.ERR, "mkdir err:[", path, "]", lerr)
            end
            return lres
        end
    end
    return res
end

-- 返回http的状态码
-- @param status 状态码
-- @param message 信息
-- @return void
function util.status(status, message)
    ngx.status = status
    ngx.say(status .. "->" .. message)
    ngx.exit(status)
end

-- 添加header头
-- @param table new_header
-- @return json string
function util.header_merge(new_header)
    if ngx.var.wafcdn_header == "" then
        return util.json_encode(new_header)
    end
    local header, _ = util.json_decode(ngx.var.wafcdn_header)
    if header == nil then
        return util.json_encode(new_header)
    end
    for key, val in pairs(header) do
        new_header[key] = header[val]
    end
    return util.json_encode(new_header)
end


function util.header_response()
    ngx.header["Server"] = "WAFCDN"
    if ngx.var.wafcdn_header ~= "" then
        local header, _ = util.json_decode(ngx.var.wafcdn_header)
        for key, val in pairs(header or {}) do
            ngx.header[key] = val
        end
    end
end

return util
