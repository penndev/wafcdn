
local limit_req = require("resty.limit.req")
local ngx = require("ngx")

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

function filter.sign()
    
end


return filter