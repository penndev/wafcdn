local ssl = require("ngx.ssl")
local common = require("common")

local ok, err = ssl.clear_certs()
if not ok then
    ngx.log(ngx.ERR, "failed to clear existing (fallback) certificates:", err)
    return ngx.exit(ngx.ERROR)
end

local name, err = ssl.server_name()
if not name then
    ngx.log(ngx.ERR, "failed to get server_name certificates:", err)
    return ngx.exit(ngx.ERROR)
end

local cert = common.sslinfo(name)
if not cert then
    ngx.log(ngx.ERR, "failed to get sslinfo:", name)
    return ngx.exit(ngx.ERROR)
end

local der_cert_chain, err = ssl.cert_pem_to_der(cert.crt)
if not der_cert_chain then
    ngx.log(ngx.ERR, "failed to convert certificate chain ", "from PEM to DER: ", err)
    return ngx.exit(ngx.ERROR)
end

local ok, err = ssl.set_der_cert(der_cert_chain)
if not ok then
    ngx.log(ngx.ERR, "failed to set DER cert: ", err)
    return ngx.exit(ngx.ERROR)
end

local der_pkey, err = ssl.priv_key_pem_to_der(cert.key)
if not der_pkey then
    ngx.log(ngx.ERR, "failed to convert private key ", "from PEM to DER: ", err)
    return ngx.exit(ngx.ERROR)
end

local ok, err = ssl.set_der_priv_key(der_pkey)
if not ok then
    ngx.log(ngx.ERR, "failed to set DER private key: ", err)
    return ngx.exit(ngx.ERROR)
end
