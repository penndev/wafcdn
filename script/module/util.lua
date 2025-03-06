local ngx = require("ngx")
local cjson = require("cjson")
local lfs = require("module.lfs")
local http = require("resty.http")
local openssl_hmac = require("resty.openssl.hmac")

cjson.encode_escape_forward_slash(false)

local util = {
    -- json编码器
    -- @param any
    -- @return string
    json_encode = cjson.encode,
    -- json解码器
    -- @param string
    -- @return
        -- nil
        -- any
    json_decode = cjson.decode,
}


-- 发起与主控网络请求
-- https://github.com/ledgetech/lua-resty-http?tab=readme-ov-file#request_uri
-- @param uri 请求网址
-- @param table 请求描述
-- @return table 返回体
function util.request(uri, opt)
    local httpc, err = http.new()
    if not httpc then
        return nil, "Failed to create http client: " .. (err or "unknown error")
    end
    httpc:set_timeout(5000) -- 5秒超时
    -- 发送 HTTP 请求
    local res, err = httpc:request_uri("http://127.0.0.1:8000"..uri, opt)
    if not res then
        return nil, "HTTP request failed: " .. (err or "unknown error")
    end
    if res.status ~= 200 then
        return nil, 'res.status ' .. res.status
    end
    local body = util.json_decode(res.body)
    if body == nil then
        return nil, 'json_decode decode fail'
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


return util
