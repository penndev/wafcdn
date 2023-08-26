-- 公共方法模块
local ffi = require("ffi")
ffi.cdef([[
    int mkdir(const char *path, int mode);
    extern int errno;
]])

local resty_lock = require("resty.lock")

local M = {}

function  M.mkdir(path, mode)
    -- local path = path:match("(.*/)") or path
    local res = ffi.C.mkdir(path, mode)
    local err = ffi.errno()
    if res == 0 then
        return true
    elseif err == 17 then -- 文件已存在。
        return true
    elseif err == 2 then -- 父级不存在
        local parent = path:gsub("/[^/]+/$", "/")
        if M.mkdir(parent,mode) then 
            -- 再次尝试本地创建
            return ffi.C.mkdir(path, mode) == 0
        else
            return false
        end
    else
        ngx.log(ngx.ERR,"Create Folder Fial: mkdri errno("..err..")" .. path)
        return false
    end
end

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

-- 缓存成功
function M.setcache(path)
    -- local file, err = io.open(path, "w")
    -- if file ~= nil then
    --     file:write(os.time())
    --     file:close()
    -- end
end

-- 验证缓存是否过期
-- path 文件路径
-- expired 缓存时间/天
-- return boolean
function M.getcache(path, expired)
    -- local file, err = io.open(path, "r")
    -- if file then
    --     local timestamp_str = file:read("*all")
    --     file:close()
    --     local timestamp = tonumber(timestamp_str)
    return os.time
    -- else
    --     return nil
    -- end
end

return M
