
local limit_req = require("resty.limit.req")
local ngx = require("ngx")
local util = require("util")

local filter = {}

-- 限流函数：根据速率、QPS（每秒查询数）和突发值来控制流量
-- @param rate number 允许的平均速率（单位：请求/秒）
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

-- 验证get签名函数
-- @param method
    -- md5
    -- sha1
-- @param key 加密密钥
-- @param timeargs 时间参数名称 ~UTC秒时间戳
-- @param signargs 签名参数名称
-- @return allow bool 是否放行
-- @return err nil 错误描述 timebefore timeafter
function filter.sign(method, key, timeargs, signargs, expires)
    -- 默认args已经排序
    local args, err = ngx.req.get_uri_args()
    if not args then --if err == "truncated" then
        return false, 'nil_get_args'
    end

    -- 设置请求过期，重放攻击等防御
    if args[timeargs] == nil then 
        return false, 'nil_args_timeargs('..timeargs..')'
    end

    -- 请求有固定的窗口期
        -- 请求时间 < 服务器时间    过时的请求 - deny
        -- 请求时间 > 过期时间      未来的请求 - deny
        -- 请求时间 in 服务器时间+超时时间    请求窗口放行 - allow
    -- 时间冗余 5 秒
        -- 服务器时间比标准快
        -- 客户端时间比标准慢
        -- 请求损耗阻塞时间过长
    local req_time = tonumber(args[timeargs])
    local current_time = os.time(os.date("!*t"))
    if (req_time < current_time - 5) then
        -- ================== 500 开发调试记住关掉
        return false, "timebefore"
    else if (req_time > current_time + tonumber(expires)) then
        return false, "timeafter"
    end
    -- 时间验证通过
    
    ngx.say(util.json_encode(args))

    ngx.say(current_time, " time ", req_time)
    -- ngx.say("<br/>")
    -- local str = util.hmac('md5', key, '123456')
    -- ngx.say(str)
    return true
end



return filter