local ngx = require("ngx")
local cjson = require("cjson")

-- json编码器
local json_encode = cjson.encode

-- json解码器
local function json_decode(str)
    local ok, t = pcall(cjson.decode, str)
    if not ok then
      return nil
    end
    return t
end

-- 发起网络请求
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

return {
    request = request,
    json_encode = json_encode,
    json_decode = json_decode
}