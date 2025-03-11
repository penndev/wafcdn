local ngx = require("ngx")
local mysql = require("resty.mysql")
local util = require("module.util")

local function new(cb)
    local db = mysql:new()
    local ok, err, errcode, sqlstate = db:connect({
        host = "127.0.0.1",
        port = 3306,
        database = "galite",
        user = "root",
        password = "123456"
    })
    db:set_timeout(1000)
    if not ok then
        ngx.log(ngx.ERR ,"failed to connect: ", err, ": ", errcode, " ", sqlstate)
        db:close()
        return nil, "failed to connect mysql"
    end

    cb(db)

    local ok, err = db:set_keepalive(10000, 100)
    if not ok then
        ngx.log(ngx.ERR,"failed to set keepalive: ", err)
        db:close()
        return
    end

end

-- -- 插入缓存
-- -- @param table data {site_id, method, uri, header, path}
-- local function InCache(data)
--     local values = "'"..data.site_id..", '"..data.method.."', '"..ngx.quote_sql_str(data.uri).."', '"..util.json_encode(data.header).."', '"..data.path.."'"
--     local sql = "INSERT INTO  `caches` ( `site_id`, `method`, `uri`, `header`, `path`) VALUES ("..values..")"
--     new(function(db)
--         local res, err, errcode, sqlstate = db:query(sql)
--         if not res then
--             ngx.log(ngx.ERR, "bad result: ", err, ": ", errcode, ": ", sqlstate, ".")
--             return
--         end
--         ngx.log(ngx.ERR, util.json_encode(res))
--     end)
-- end



-- return {
--     InCache = InCache
-- }