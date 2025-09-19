local lfs = require("lfs")
local ngx = require("ngx")


-- 设置工作目录
local prefix = ngx.config.prefix()
local ok, err = os.execute("cd " .. prefix)
if not ok then
    error("failed to set working dir: " .. err)
end

-- 放置缓存文件的目录
local wafcdn_data_dir = os.getenv("WAFCDN_DATA_DIR")
if wafcdn_data_dir == "" then
    error("env WAFCDN_DATA_DIR not set")
end
if lfs.attributes(wafcdn_data_dir, 'mode') ~= 'directory' then
    error("env WAFCDN_DATA_DIR (" .. wafcdn_data_dir .. ") not is directory type")
end


-- 交互的API接口地址
local wafcdn_api = os.getenv("WAFCDN_API")
if wafcdn_api == "" then
    error("env WAFCDN_API not set")
end

-- 交互的API接口超时时间
local wafcdn_api_timeout = tonumber(os.getenv("WAFCDN_API_TIMEOUT"))
if wafcdn_api_timeout == nil then
    wafcdn_api_timeout = 30000
end

-- 启动时读取 HTML 模板
local wafcdn_template_error = nil
local errorfile = io.open("./script/template/error.html", "r")
if errorfile then
    wafcdn_template_error = errorfile:read("*a")
    errorfile:close()
end
-- 启动时读取 HTML 模板
local wafcdn_template_captcha = nil
local captcha_file = io.open("./script/template/captcha.html", "r")
if captcha_file then
    wafcdn_template_captcha = captcha_file:read("*a")
    captcha_file:close()
end



return {
    WAFCDN_API = wafcdn_api,
    WAFCDN_API_TIMEOUT = wafcdn_api_timeout,
    WAFCDN_DATA_DIR = wafcdn_data_dir,
    WAFCDN_TEMPLATE_ERROR = wafcdn_template_error,
    WAFCDN_TEMPLATE_CAPTCHA = wafcdn_template_captcha
}