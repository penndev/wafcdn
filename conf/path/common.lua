-- 公共方法模块
local M = {}

local lfs = require("lfs")
local http = require("http")
local json = require("cjson")

local getHttpHost = function(premature, rq)
    local httpc = http.new()
    local url = rq.url.."/getdomaininfo?host="..rq.host
    local res, err = httpc:request_uri(url)
    if err ~= nil then
        ngx.log(ngx.ERR, "getHttpHost() request_uri error:[", err, "]("..url..")")
        return
    end
    if res and res.status == 200 then
        local success, err, forcible = ngx.shared.domain:set(rq.host, res.body, 30)
        if err ~= nil then 
            ngx.log(ngx.ERR, "getHttpHost() domain set error:[".. err.."]")
        end
        return doamininfo
    else
        ngx.log(ngx.ERR, "getHttpHost() request_uri bad:[".. res.status.."]", res.body)
    end
    return nil
end

-- 获取域名的配置信息
-- host 请求的域名
-- return 域名配置的信息
function M.hostinfo(host)
    local rq = { url = ngx.var.domain_url, host = ngx.var.host}
    local value, flags, stale = ngx.shared.domain:get_stale(rq.host)
    if value ~= nil then -- 存在则直接返回。
        if stale then 
            ngx.timer.at(0,getHttpHost,rq)
        end
        local doamininfo, err = json.decode(value)
        if err ~= nil then
            ngx.log(ngx.ERR, "hostinfo() cjson decode error:[", err, "(]"..rq.host..")")
        end
        return doamininfo
    else 
        local success, err, forcible = ngx.shared.domain_lock:add(rq.host.."_lock", true, 30)
        if err and err ~= "exists" then -- 有异常情况。
            ngx.log(ngx.ERR, "ngx.shared.domain_lock>>", err)
        end
        if forcible then
            ngx.log(ngx.ERR, "ngx.shared.domain_lock no memory")
        end
        if success then
            ngx.timer.at(0,getHttpHost,rq)
        end
    end
    return nil
end

-- 验证缓存是否过期
-- path 文件路径
-- expired 缓存时间/天
-- return boolean
function M.getcache(path, expired)
    local modification, err  = lfs.attributes(path, "modification")
    if modification then
        local expired_time = expired * 60 + modification
        if expired_time > os.time() then
            return true
        end
    end
    return false
end

-- 给缓存加锁
function M.docachelock(path,expired)
    local success, err, forcible = ngx.shared.cache:add(path, true, expired)
    if forcible then
        ngx.log(ngx.ERR, "ngx.shared.cache no memory")
    end
    if err and err ~= "exists" then
        ngx.log(ngx.ERR, "ngx.shared.cache", err)
    end
    return success
end




-- 重新缓存文件
function M.redownload(premature, downData, cacheData)
    local httpc = http.new()
    local res, err = httpc:request_uri(downData.url, downData.params)
    if res.status == 200 then
        downData.file:seek("set")
        file:write(res.body)
        downData.file:close()
        M.setcache(premature,cacheData)
    else
        os.remove(cacheData.path)
    end
    httpc:close()
end


-- 缓存成功
-- 调用端口处理缓存目录。
-- cacheData{site, url, path, size, expired}网站id,请求地址,文件路径,过期时间,
function M.setcache(premature ,cacheData)
    local httpc = http.new()
    local res, err = httpc:request_uri(cacheData.url, {
        method = "POST",
        body = json.encode({
            SiteID = cachedata.identity,
            Path = cachedata.uri,
            File = cachedata.path,
            Size = cachedata.size,
            Accessed = os.time(),
            Expried = os.time() + (cacheData.time * 60)
        }),
        headers = {
            ["Content-Type"] = "application/json",
        },
    })
    print("通知缓存结果>>>"..res.status.."|"..res.body.."<<<<")
end


-- 计算路径的md5路径
function M.md5path(uri)
    local md5 = ngx.md5(uri)
    local dir1, dir2 = md5:sub(1, 2), md5:sub(3, 4)
    return string.format("/%s/%s/%s", dir1, dir2, md5)
end

-- 递归创建缓存目录
function M.mkdir(path)
    local res, err = lfs.mkdir(path)
    if not res then
        local parent = path:gsub("/[^/]+/$", "/")
        if M.mkdir(parent) then
            local res, err = lfs.mkdir(path)
            if err ~= nil then ngx.log(ngx.ERR, "创建文件夹失败[".. path .. "]", err) end
            return res
        end
    end
    return res
end
return M
