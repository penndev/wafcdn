-- 公共方法模块
local envTable = {}

---清除字符串首尾的空格和字符
---@param val string
---@return string
local function trim(val)
    return string.match(val, "^%s*(.*%S)")
end

---加载env文件并设置 env key value
---@param filepath string?
---@return nil
local function loadenv(filepath)
    if not filepath then
        filepath = ".env"
    end
    local envfile = io.open(filepath, "r")
    if not envfile then
        error("can't load the env file:" .. filepath)
    end
    for line in envfile:lines() do
        local key, value = line:match("^([^=]+)=(.+)$")
        key = trim(key)
        value = trim(value)
        if key and value then
            envTable[key] = value
        end
    end
end

---返回经过处理env文件
---@param key string
---@return string?
---@nodiscard
local function getenv(key)
    if envTable[key] then
        return envTable[key]
    end
    return os.getenv(key)
end

---覆盖env变量的key value
---@param key string
---@param value string
---@return nil
local function setenv(key, value)
    envTable[key] = value
end

return {
    loadenv = loadenv,
    getenv=getenv,
    setenv=setenv,
    trim=trim,
}
