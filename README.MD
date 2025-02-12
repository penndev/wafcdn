# WAFCDN

> 基于openresty开发的服务器网关，融合waf和cdn的功能。

## WAF功能 ×


- 单连接限速
- QPS限制
- CC防御
- IP黑白名单
- IP地域限制
- 客户端token校验(网页验证码)

## CDN加速分发

- 使用nginx原生ngx_http_proxy_module模块来进行回源处理，稳定。

- 使用nginx原生ngx_http_core_module的静态文件模块来快速处理缓存响应。

- 使用nginx lua module来完成缓存高效的动态匹配与响应。

## WAFCDN后台管理

> 使用golang编写的api来操作整体的wafcdn运行情况 

- 域名配置 waf cdn的功能。
- 缓存管理 预加载，清理。
- 运行监控服务器的运行情况等功能。


## openresty 生命周期图

![流程图](https://raw.githubusercontent.com/openresty/lua-nginx-module/refs/heads/master/doc/images/lua_nginx_modules_directives.drawio.png)

## 环境安装

自助安装脚本 https://gist.github.com/penndev/9f01b3864abe2368424d3a79f5efff7e


## 快速开发调试重启

openresty -p ./ -s stop && sleep 2 && rm -f logs/error.log && openresty -p ./

## openssl 依赖
https://github.com/fffonion/lua-resty-openssl

标准UTC0时区时间 Math.ceil(Date.now()/1000) + (new Date().getTimezoneOffset() * 60)