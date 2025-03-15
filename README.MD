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




## 快速开发调试重启

openresty -p ./ -s stop && sleep 2 && rm -f logs/error.log && openresty -p ./



# 签名与加密

JS标准UTC0时区的秒时间戳: `Math.ceil(Date.now()/1000) + (new Date().getTimezoneOffset() * 60)`



## 缓存管理 
- 如果缓存命中信息
    `cache-control` 缓存规则时间
    `X-Cache` 是否命中缓存文件
    `Age` 缓存存活时间

- 缓存动作
    一次缓存动作 通过 `ngx.shared.cache_key` 来做锁，防止多线程污染缓存。

- 缓存结果
    - 文件请求中断，缓存的文件会被清理
    - Range 请求会被被忽略缓存动作（因为range通常为大文件，直接回源的话!缓存穿透攻击!）

# openssl 说明

![流程图](https://raw.githubusercontent.com/openresty/lua-nginx-module/refs/heads/master/doc/images/lua_nginx_modules_directives.drawio.png)


```
# 启动
openresty -p ./ 

```


Q 为什么要用三方库，而不是默认的`ngx.md5`这些
A 支持更全面，默认的几个加密方法太少。

```
opm get fffonion/lua-resty-openssl
```

Q 为什么使用http库而不是 `ngx.location.capture`
A location在一些周期不可用。
```
opm get ledgetech/lua-resty-http
```
