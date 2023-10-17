local ssl = require("ngx.ssl")
local lock = require("resty.lock")
local http = require("http")
local json = require("cjson")
local init = require("init")
local ngx = require("ngx")

local sharedttl = init.sharedttl
local sslurl = init.socketapi
local socketClient = function(_, hostname)
    local my_lock, mylockerr = lock:new("ssl_lock")
    if not my_lock then
        ngx.log(ngx.ERR, "cant create ssl_lock:", mylockerr)
        return
    end
    local locked, lockerr = my_lock:lock(hostname)
    if not locked then
        ngx.log(ngx.ERR, "cant lock ssl_lock:", lockerr)
        return
    end
    -- 验证自己是锁的持有者还是等待者
    local value, _ = ngx.shared.ssl:get(hostname)
    if value then
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock ssl_lock:", err)
        end
        local crt, key = string.match(tostring(value), "(.-)%$(.+)")
        return { crt = crt, key = key }
    end
    -- 强制限制避免回源失败的缓存穿透
    local locksuccess, lockadderr, lockforcible = ngx.shared.ssl_lock:add(hostname .. ".lock", true, sharedttl)
    if lockadderr and lockadderr ~= "exists" then
        ngx.log(ngx.ERR, "ngx.shared.ssl_lock err:", lockadderr)
    end
    if lockforcible then
        ngx.log(ngx.ERR, "ngx.shared.ssl_lock no memory")
    end
    if not locksuccess then
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock ssl_lock:", err)
        end
        return
    end
    -- 没有人获取结果，那么我就是缓存的执行者
    local httpc = http.new()
    if not httpc then
        ngx.log(ngx.ERR, "http.new return nil")
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock ssl_lock:", err)
        end
        return
    end
    local res, reqerr = httpc:request_uri(sslurl .. "/socket/ssl?host=" .. hostname)
    httpc:close()
    if not res then
        ngx.log(ngx.ERR, "httpc:request_uri err:", reqerr)
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock ssl_lock:", err)
        end
        return
    end
    if res.status == 200 then
        local certmeta = json.decode(res.body)
        local crt = ngx.decode_base64(certmeta.crt)
        local key = ngx.decode_base64(certmeta.key)
        local success, sslerr, forcible = ngx.shared.ssl:set(hostname, crt .. "$" .. key, sharedttl)
        if sslerr or not success then
            ngx.log(ngx.ERR, "ngx.shared.ssl set err:", sslerr)
        end
        if forcible then
            ngx.log(ngx.ERR, "ngx.shared.ssl no memory")
        end
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock ssl_lock:", err)
        end
        return { crt = crt, key = key }
    else
        ngx.log(ngx.INFO, "status:", res.status, "|body:", res.body)
        local ok, err = my_lock:unlock()
        if not ok then
            ngx.log(ngx.ERR, "cant unlock ssl_lock:", err)
        end
        return
    end
end

---从socket api获取域名证书
---@param host string
---@return table? {key:string,pem:string}
local function getSocketSSL(host)
    local value, flags, stale = ngx.shared.ssl:get_stale(host)
    if value then
        if stale then -- 存在但是过期了
            local ok, err = ngx.timer.at(0, socketClient, host)
            if not ok then
                ngx.log(ngx.ERR, "sslinfo() cont create ngx.timer err:", err)
            end
        end
        local crt, key = tostring(value):match("(.-)%$(.+)")
        return { crt = crt, key = key }
    end
    return socketClient(0, host)
end

--- runtimed进行动态ssl验证
local function setup()
    local hostname, hostnameerr = ssl.server_name()
    if not hostname then
        ngx.log(ngx.INFO, "failed to get server_name certificates:", hostnameerr)
        return ngx.exit(ngx.ERROR)
    end

    local cert = getSocketSSL(hostname)
    if not cert then
        ngx.log(ngx.INFO, "failed to get sslinfo:", hostname)
        return ngx.exit(ngx.ERROR)
    end

    local clearok, clearerr = ssl.clear_certs()
    if not clearok then
        ngx.log(ngx.ERR, "failed to clear existing (fallback) certificates:", clearerr)
        return ngx.exit(ngx.ERROR)
    end

    local der_cert_chain, crterr = ssl.cert_pem_to_der(cert.crt)
    if not der_cert_chain then
        ngx.log(ngx.ERR, "failed to convert certificate chain from PEM to DER: ", crterr)
        return ngx.exit(ngx.ERROR)
    end

    local chainok, chainerr = ssl.set_der_cert(der_cert_chain)
    if not chainok then
        ngx.log(ngx.ERR, "failed to set DER cert:", chainerr)
        return ngx.exit(ngx.ERROR)
    end

    local der_pkey, keyerr = ssl.priv_key_pem_to_der(cert.key)
    if not der_pkey then
        ngx.log(ngx.ERR, "failed to convert private key from PEM to DER:", keyerr)
        return ngx.exit(ngx.ERROR)
    end

    local privok, priverr = ssl.set_der_priv_key(der_pkey)
    if not privok then
        ngx.log(ngx.ERR, "failed to set DER private key:", priverr)
        return ngx.exit(ngx.ERROR)
    end
end

return {
    setup = setup
}
