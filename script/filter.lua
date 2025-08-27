
local limit_req = require("resty.limit.req")
local ngx = require("ngx")
local util = require("util")

local filter = {}

-- 限流函数：根据速率、QPS（每秒查询数）和突发值来控制流量
-- @param rate number 允许的流量速率（单位：请求速度 kb/s）
-- @param qps number 允许的最大 QPS（每秒查询数）
-- @param burst number 允许的突发请求数（短时间内允许的最大请求数）也就是合计burst/qps秒内允许的最多请求。
function filter.limit(rate, qps, burst)
    if qps > 0 then
        local lim, err = limit_req.new("limit_req", qps, burst)
        if not lim then
            ngx.log(ngx.ERR, "failed to instantiate a resty.limit.req object : ", err)
            return true
        end

        local key = ngx.var.binary_remote_addr
        local delay, err = lim:incoming(key, true)
        if not delay then
            ngx.log(ngx.ERR, "failed to limit req: ", err)
            return true
        end
        if delay > 0 then
            return false
        end
    end

    -- 单链接限速下载速度
    if rate > 0 then
        ngx.var.limit_rate = rate .. "k"
    end
    return true
end

-- 进行get签名验证
-- @param method
    -- md5
    -- sha1
-- @param key 加密密钥
-- @param timeArgs 时间参数名称 ~UTC秒时间戳
-- @param signArgs 签名参数名称
-- @return allow bool 是否放行
-- @return err nil 错误描述 timeBefore timeAfter
function filter.sign(method, key, expireArgs, signArgs)
    -- 默认args已经排序
    local args, _ = ngx.req.get_uri_args()
    if not args then
        return false, 'no_args' --不存在参数
    end
    -- 设置请求过期。
    if not args[expireArgs] then
        return false, 'no_args_expire' -- 不存在过期参数
    end
    local expire_time = tonumber(args[expireArgs])
    local current_time = os.time()
    if (expire_time < current_time) then
        return false, "expire" -- 请求过期
    end

    -- 设置签名校验
    if not args[signArgs] then
        return false, 'no_args_sign' -- 不存在签名参数
    end
    local signStr = expireArgs.."="..args[expireArgs].."&"..signArgs.."="..args[signArgs]
    local startPos, endPos = string.find(ngx.var.request_uri, signStr)
    if endPos ~= string.len(ngx.var.request_uri) then
        return false, 'sign_no_end' -- 签名排序不对 签名部分应该是追加在尾部
    end
    local pos = startPos + string.len(expireArgs.."="..args[expireArgs])
    local origin_uri = string.sub(ngx.var.request_uri, 0, pos - 1)
    local secret = ''
    if method == 'HMAC_MD5' then
        secret = util.hmac('md5', key, origin_uri)
    elseif method == 'HMAC_SHA1' then
        secret = util.hmac('sha1', key, origin_uri)
    elseif method == 'HMAC_SHA256' then
        secret = util.hmac('sha256', key, origin_uri)
    else
        return false, 'sign_no_method' -- 后台签名配置方法不对
    end
    local base_secret = util.base64_url_encode(secret)
    if base_secret ~= args[signArgs] then
        return false, 'sign_fail' -- 签名验证失败
    end
    return true
end

return filter
