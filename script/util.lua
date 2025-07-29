local ngx = require("ngx")
local init = require("init")
local lock = require("resty.lock")
local cjson = require("cjson")
local lfs = require("lfs")
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
    local function request(uri, opt)
        local url = init.WAFCDN_API .. uri
        local msg = "WAFCDN_INTERNAL_HTTP_FAIL"
        local client, err = http.new()
        if not client then
            ngx.log(ngx.ERR, "Failed to create http client: ", err)
            return nil, msg
        end
        client:set_timeout(init.WAFCDN_API_TIMEOUT) -- 3秒超时
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
        return {
            headers = res.headers,
            status = res.status,
            body = body,
        }
    end
    -- 缓存http结果
    if opt and opt.cache and opt.cache > 0 then
        local cache_key = ngx.md5(uri..util.json_encode(opt))
        -- 读取缓存
        local value, _ = ngx.shared.request:get(cache_key)
        if value then
            return util.json_decode(value)
        end

        -- 加缓存所锁
        local request_lock, err = lock:new("request_lock")
        if not request_lock then
            ngx.log(ngx.ERR, "cant create request_lock:", err)
            return nil, "INTERNAL_LOCK_NEW_FAIL"
        end
        local locked, err = request_lock:lock(cache_key)
        if not locked then
            ngx.log(ngx.ERR, "cant lock request:", err)
            return nil, "INTERNAL_LOCK_FAIL"
        end

        local unlock = function()
            local ok, err = request_lock:unlock()
            if not ok then
                ngx.log(ngx.ERR, "cant unlock request_lock:", err)
            end
        end

        -- 锁的持有者已经填充缓存
        local value, _ = ngx.shared.request:get(cache_key)
        if value then
            unlock()
            return util.json_decode(value)
        end
        local res, err = request(uri, opt)
        unlock()
        if res then
            local data,err = util.json_encode(res)
            if not data then
                ngx.log(ngx.ERR, "json encode err:", err)
            end
            local success, err, forcible = ngx.shared.request:set(cache_key, data, opt.cache)
            if err or not success then
                ngx.log(ngx.ERR, "ngx.shared.request set err:", err)
            end
            if forcible then
                ngx.log(ngx.ERR, "ngx.shared.request no memory")
            end
        end
        return res, err
    end
    return request(uri, opt)
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
    -- 原始 header 解析
    if ngx.var.wafcdn_header == "" then
        return util.json_encode(new_header)
    end
    local header, _ = util.json_decode(ngx.var.wafcdn_header)
    if header == nil then
        return util.json_encode(new_header)
    end
    -- 创建小写 key 映射：lower_key -> original_key
    local key_map = {}
    for k, _ in pairs(header) do
        key_map[string.lower(k)] = k
    end
    -- 合并 new_header
    for k, v in pairs(new_header) do
        local lower_k = string.lower(k)
        if v == "" then
            -- 删除某个header的实现
            header[k] = v
        else
            local origin_key = key_map[lower_k]
            if origin_key then
                -- 已存在该 header（大小写无关），更新值
                -- 最早设置的有最高的权重
                -- 取消注释则取反
                -- header[origin_key] = v
            else
                header[k] = v
                key_map[lower_k] = k
            end
        end
    end
    return util.json_encode(header)
end


function util.header_response()
    if ngx.var.wafcdn_header ~= "" then
        local header, _ = util.json_decode(ngx.var.wafcdn_header)
        ngx.header.Server = 'wafcdn'
        for key, val in pairs(header or {}) do
            if val and val == "" then
                ngx.header[key] = nil
            else
                ngx.header[key] = val
            end
        end
    end
end

function util.log()
    local data = {
        -- 站点信息
        site_id = tonumber(ngx.var.wafcdn_site),
        host = ngx.var.host,
        -- 客户端信息
        remote_addr = ngx.var.remote_addr,
        http_referer = ngx.req.get_headers()["referer"] or "",
        http_user_agent = ngx.req.get_headers()["user_agent"] or "",
        -- 请求信息
        request = ngx.var.request_uri,
        request_method = ngx.var.request_method,
        request_time = ngx.var.request_time,
        -- 传输信息
        status = tonumber(ngx.var.status),
        bytes_received = tonumber(ngx.var.request_length),
        bytes_sent = tonumber(ngx.var.bytes_sent)
    }
    local handle = function()
        local res, err = util.request("/@wafcdn/log", {
            method = "PUT",
            headers = {
                ["Content-Type"] = "application/json"
            },
            body = util.json_encode(data)
        })
        if not res or res.status ~= 200 then
            ngx.log(ngx.ERR, " /@wafcdn/log error:", err)
        end
    end
    ngx.timer.at(0, handle)
end

return util
