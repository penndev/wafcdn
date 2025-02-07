
local limit_req = require("resty.limit.req")
local ngx = require("ngx")

local filter = {}

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

return filter