# WAFCDN

> 基于openresty开发的服务器网关，融合waf和cdn的功能。

## WAF功能
- 单连接限速
- QPS限制
- CC签名防御
- IP地域限制
- IP地域+黑白名单

**todo**
- 客户端token校验(网页验证码)
- PURGE 请求方法支持，清理缓存


## CDN功能

### 反向代理

- 连接池配置
    - 保持活跃的连接数量
    - 单连接存活时间/秒

- 使用nginx `ngx_http_proxy_module` 模块回源
    - 直接使用域名回源
    - 可自定义回源`Host`

- 缓存 `X-Cache`
    - `MISS` 命中缓存规则，会输出 `Cache-Control` 来显示缓存配置时间
    - `HIT` 命中缓存，会输出 `Cache-Control` `Age` 显示缓存详情
    - `ERROR` 缓存中断 http返回的状态码与预期不符

- 使用nginx `ngx_http_core_module` 模块来响应缓存
    - 支持http-range请求

## 后台管理

> 使用golang编写的api来操作整体的wafcdn运行情况 

- 域名配置 waf cdn的功能。
- 缓存管理 预加载，清理。
- 运行监控服务器的运行情况等功能。

### 缓存管理 
- 如果缓存命中信息
    `cache-control` 缓存规则时间
    `X-Cache` 是否命中缓存文件
    `Age` 缓存存活时间

- 缓存动作
    一次缓存动作 通过 `ngx.shared.cache_key` 来做锁，防止多线程污染缓存。

- 缓存结果
    - 文件请求中断，缓存的文件会被清理
    - Range 请求会被被忽略缓存动作（因为range通常为大文件，直接回源的话!缓存穿透攻击!）

## 运行配置

- 创建日志目录

    ```bash
    mkdir logs
    ```

- 生成占位证书

    ```bash
    cd conf
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout private.key -out certificate.crt -config ssl.conf
    ```

- 配置缓存目录 `conf/nginx.conf` 下的 `WAFCDN_DATA_DIR` 配置

Docker启动命令

```bash
# 小并发单机部署命令
docker run -e DB_URL=sqlite://sqlite.db -e CACHE_URL=ttlmap://memory -d -p 80:80 -p 443:443 -p 8000:8000 -e APP_SECRET=secret penndev/wafcdn:latest

# 高并发运行
docker run -e DB_URL=postgres://postgres:123456@127.0.0.1:5432/wafcdn -e CACHE_URL=redis://default:@127.0.0.1:6379/1 -d -p 80:80 -p 443:443 -p 8000:8000 -e APP_SECRET=secret penndev/wafcdn:latest
```

## openresty 说明

- 快速开发调试重启 `openresty -p ./ -s stop && sleep 2 && rm -f logs/error.log && openresty -p ./`

![流程图](https://raw.githubusercontent.com/openresty/lua-nginx-module/refs/heads/master/doc/images/lua_nginx_modules_directives.drawio.png)


**依赖项**

> 已经将依赖项本地化 ./script/resty 目录下

```bash
# Q 为什么要用三方库，而不是默认的`ngx.md5`这些
# A 支持更全面，默认的几个加密方法太少。

opm get fffonion/lua-resty-openssl
 
# Q 为什么使用http库而不是 `ngx.location.capture`
# A location在一些周期不可用。
 
opm get logitech/lua-resty-http

# 生成文件夹处理文件等
opm get spacewander/luafilesystem
```
