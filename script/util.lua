local ngx = require("ngx")
local cjson = require("cjson")
local openssl_hmac = require("resty.openssl.hmac")

-- json编码器
-- @param any
-- @return string
cjson.encode_escape_forward_slash(false)
local json_encode = cjson.encode

-- json解码器
-- @param string
-- @return 
    -- nil 
    -- any
local json_decode = cjson.decode
-- local function json_decode(str)
--     local ok, t = pcall(cjson.decode, str)
--     if not ok then
--       return nil
--     end
--     return t
-- end

-- 发起网络请求
-- https://github.com/openresty/lua-nginx-module?tab=readme-ov-file#ngxlocationcapture
-- @param uri 请求网址
-- @param table 请求描述
-- @return table 返回体
local function request(uri, opt)
    local res = ngx.location.capture(uri, opt)
    if res.truncated ~= false then
        return nil, 'res.truncated true'
    end
    if res.status ~= 200 then
        return nil, 'res.status ' + res.status
    end
    local body = json_decode(res.body)
    if body == nil then 
        return nil, 'json_decode decode fail'
    end
    return {header = res.header, body = body}, nil
end

-- base64 url编码
local function base64_url_encode(char)
    return ngx.encode_base64(char):gsub("+", "-"):gsub("/", "_"):gsub("=", "")
end

-- hmac算法
-- @param method hmac算法
-- @param key 加密的key
-- @param message 加密的消息
-- @return hex string 结果
local function hmac(method, key, message)
    local hmac_method = openssl_hmac.new(key, method)
    hmac_method:update(message)
    return hmac_method:final()
end

return {
    json_encode = json_encode,
    json_decode = json_decode,
    base64_url_encode = base64_url_encode,
    request = request,
    hmac = hmac
}