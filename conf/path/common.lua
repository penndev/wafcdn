-- 公共方法表
local M = {}

function M.hostinfo(host)
    -- ngx.log(ngx.NOTICE, "请求域名配置信息，保持结构体不然数据显得冗杂。" .. host)
    local configinfo = {
        back = {
            url = "http://127.0.0.1", 
            host = "www.baidu.com",
            header = {
                { header_name = "X-MY-NAME", header_value = "penndev" },
                { header_name = "X-MY-NAME1", header_value = "penndev1" },
            }
        },
        cache = {
            { cache_key = "%.mp4$", cache_time = 2000 },
            { cache_key = "%.css$", cache_time = 2000 },
            { cache_key = "%.zip$", cache_time = 2000 },
            { cache_key = "^/cc", cache_time = 2000 }
        },
        limit = {
            status = 1,
            qps = 100,
            rate = 100
        }
    }
    return configinfo
end


function M.set_cache(path)
    local file, err = io.open(path, "w")
    if file ~= nil then
        file:write(os.time())
        file:close()
    end
end

function M.get_cache(path)
    local file, err = io.open(path, "r")
    if file then
        local timestamp_str = file:read("*all")
        file:close()
        local timestamp = tonumber(timestamp_str)
        return timestamp
    else
        return nil
    end    
end




return M
