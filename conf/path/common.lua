-- 公共方法模块
local resty_lock = require("resty.lock")
local lfs = require("lfs")
local M = {}


-- 获取域名的配置信息
-- host 请求的域名
-- return 域名配置的信息
function M.hostinfo(host)
    -- 直接返回内容
    local value, flags = ngx.shared.hostinfo:get(host)
    if value ~= nil then
        return value
    end

    -- 加锁防止并发
    local locks, err = resty_lock:new("locks")
    if not locks then
        ngx.log(ngx.ERR, "无法创建锁: ", err)
    end

    local elapsed, err = locks:lock(host)
    if not elapsed then
        ngx.log(ngx.ERR, "无法获取锁: ", err)
    end
    
    
    local configinfo = {
        dir = "127.0.0.1",
        back = {
            url = "http://127.0.0.1", 
            host = "www.baidu.com",
            header = {
                { header_name = "X-MY-NAME", header_value = "penndev" },
            }
        },
        cache = {
            { cache_key = "^/cc", cache_time = 2000 }
        },
        limit = {
            status = 1,
            qps = 100,
            rate = 100
        }
    }
    -- 添加到共享内存
    ngx.shared.hostinfo:set(host, configinfo, 300)
    -- 释放锁
    local ok, err = locks:unlock()
    if not ok then
        ngx.log(ngx.ERR, "无法释放锁: ", err)
    end

    return configinfo
end

function M.md5path(uri)
    local md5 = ngx.md5(uri)
    local dir1, dir2 = md5:sub(1, 2), md5:sub(3, 4)
    return string.format("/%s/%s/%s", dir1, dir2, md5)
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
    local success, err, forcible = ngx.shared.docache:add(path, true, expired)
    if forcible then
        ngx.log(ngx.ERR, "ngx.shared.docache no memory")
    end
    if err and err ~= "exists" then
        ngx.log(ngx.ERR, "ngx.shared.docache", err)
    end
    return success
end

-- 缓存成功
-- 调用端口处理缓存目录。
function M.setcache(path)

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
