
local limit_req = require("resty.limit.req")
local ngx = require("ngx")
local util = require("util")
local init = require("init")

local filter = {}

-- 限流函数：根据速率、QPS（每秒查询数）和突发值来控制流量
-- @param rate number 允许的流量速率（单位：请求速度 kb/s）
-- @param qps number 允许的最大 QPS（每秒查询数）
-- @param burst number 允许的突发请求数（短时间内允许的最大请求数）也就是合计burst/qps秒内允许的最多请求。
-- @return 返回真则限制
function filter.limit(qps, burst)
    if qps > 0 then
        local lim, err = limit_req.new("limit_req", qps, burst)
        if not lim then
            ngx.log(ngx.ERR, "failed to instantiate a resty.limit.req object : ", err)
            return true
        end

        local key = ngx.var.binary_remote_addr
        local delay, err = lim:incoming(key, true)
        if not delay then
            if err == "rejected" then
                return true -- 超过 rate+burst → 拒绝
            end
            ngx.log(ngx.ERR, "lim:incoming error: ", err) -- 拦截失效
            return false
        end
        if delay > 1 then
            return true
        end
        if delay > 0 then
            -- return false
            ngx.sleep(delay)
        end
    end
    return false
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

-- 挑战验证
-- @return allow bool 是否放行
-- captcha<<<
-- id
-- imageBase64
-- imageHeight
-- imageWidth
-- pieceBase64
-- pieceHeight
-- pieceWidth
-- verifyX
-- verifyY
-- >>>
function filter.captchaHtml(captcha)
    local shareCaptcha = ngx.shared.wafcdn_captcha
    shareCaptcha:set(captcha.id, captcha.verifyX*1000+captcha.verifyY, 60)   -- 保存数字

    local html = init.WAFCDN_TEMPLATE_CAPTCHA
    html = html:gsub("{{imageBase64}}", tostring(captcha.imageBase64)):gsub("{{imageHeight}}", captcha.imageHeight):gsub("{{imageWidth}}", captcha.imageWidth)
    html = html:gsub("{{pieceBase64}}", tostring(captcha.pieceBase64)):gsub("{{pieceHeight}}", captcha.pieceHeight):gsub("{{pieceWidth}}", captcha.pieceWidth)
    html = html:gsub("{{id}}", captcha.id):gsub("{{message}}", captcha.message)

    ngx.header["Content-Type"] = "text/html; charset=utf-8"
    ngx.status = 200
    ngx.say(html)
    ngx.exit(200)
end

-- wafcdn验证验证码
-- @returns allow bool 是否放行
-- @returns err string 错误描述
function filter.captchaVerify()
    if ngx.req.get_method() == "POST" then
        ngx.req.read_body()
        local args, err = ngx.req.get_post_args()
        if err then
            return err
        end
        if args["id"] == nil or args["x"] == nil or args["y"] == nil  then
            return 'no_args' -- 参数不完整
        end
        local x = tonumber(args["x"])
        local y = tonumber(args["y"])
        if x == nil or y == nil then
            return 'args_error' -- 参数错误
        end

        local shareCaptcha = ngx.shared.wafcdn_captcha
        local pos = shareCaptcha:get(args["id"])
        if not pos then
            return 'not_found' -- 未找到验证码
        end
        shareCaptcha:delete(args["id"]) -- 删除验证码
        local vx = math.floor(pos / 1000)
        local vy = pos % 1000
        if math.abs(vx - x) > 5 or math.abs(vy - y) > 5 then
            return 'verify_fail' -- 验证失败
        end
        -- 设置cookie
        local secret = util.hmac('sha256', "wafcdn", args["id"])
        secret = args["id"] .. "." .. util.base64_url_encode(secret)
        ngx.header["Set-Cookie"] = "X-WAFCDN-TOKEN="..secret.."; Path=/; HttpOnly; SameSite=Strict; Max-Age=36000"
        ngx.redirect(ngx.var.request_uri, 302)
        ngx.exit()
        return true
    end
    return "" -- 不是POST请求则替换错误消息为空字符串，不能为nil
end



-- 验证是否存在token
-- @return allow bool 是否放行
function filter.captchaToken()
    local cookie = ngx.var.http_cookie or ""
    local token = cookie:match("X%-WAFCDN%-TOKEN=([^;]+)")
    if not token then
        return false
    end
    local id, sign = token:match("^([^.]+)%.([^.]+)$")
    if not id or not sign then
        return false
    end
    local secret = util.hmac('sha256', "wafcdn", id)
    if util.base64_url_encode(secret) ~= sign then
        return false
    end
    -- 删除 X-WAFCDN-TOKEN
    local new_cookie = cookie:gsub("X%-WAFCDN%-TOKEN=[^;]*;?%s*", "")
    if new_cookie == "" then
        ngx.req.clear_header("Cookie")
    else
        ngx.req.set_header("Cookie", new_cookie)
    end
    return true
end

return filter
