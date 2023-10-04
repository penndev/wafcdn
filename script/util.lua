-- 公共方法模块

---清除字符串首尾的空格和字符
---@param val string
---@return string
local function trim(val)
    return string.match(val, "^%s*(.*%S)")
end

---返回经过处理env文件
---@param key string
---@return string?
---@nodiscard
local function getenv(key)
    return os.getenv(key)
end


return {
    getenv=getenv,
    trim=trim,
}
