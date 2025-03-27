local lfs = require("module.lfs")

-- 放置缓存文件的目录
local wafcdn_data_dir = os.getenv("WAFCDN_DATA_DIR")
if wafcdn_data_dir == "" then
    error("env WAFCDN_DATA_DIR not set")
end
if lfs.attributes(wafcdn_data_dir, 'mode') ~= 'directory' then
    error("env WAFCDN_DATA_DIR not directory")
end


-- 交互的API接口地址
local wafcdn_api = os.getenv("WAFCDN_API")
if wafcdn_api == "" then
    error("env WAFCDN_API not set")
end

-- 交互的API接口超时时间
local wafcdn_api_timeout = tonumber(os.getenv("WAFCDN_API_TIMEOUT"))
if wafcdn_api_timeout == nil then
    wafcdn_api_timeout = 3000
end

return {
    WAFCDN_API = wafcdn_api,
    WAFCDN_API_TIMEOUT = wafcdn_api_timeout,
    WAFCDN_DATA_DIR = wafcdn_data_dir
}