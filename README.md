# WAFCDN

> 基于openresty开发的服务器网关，融合waf和cdn的功能。

## Docker 安装

拉取后直接运行：

```bash
docker pull penndev/wafcdn:latest
docker run -d --network host -e APP_SECRET=secret penndev/wafcdn:latest
```

- 管理端：http://ip:8000/-admin
- 首次登录用户名填 `admin`，密码自己定；提示「已初始化管理员」后再用同一账号登录一次

**高级部署与详情见 [Docker.md](./Docker.md)**

## WAF功能
- 单连接限速
- QPS限制
- CC签名防御
- IP地域限制
- IP地域+黑白名单
- 客户端token校验(网页验证码)
- PURGE 请求方法支持，清理缓存

**TODO**
- 日志分析
- 缓存预热


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

- 管理端地址：`http://127.0.0.1:8000/-admin`（端口由 `APP_LISTEN` 控制，默认 `:8000`）
- 首次初始化：用户名必须是 `admin`，密码自定义。第一次会提示「已初始化管理员」，再用同一账号登录即可。
- `APP_SECRET` 只用于 JWT 签名，和登录密码无关。 

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

- 配置数据根目录：Go 环境变量 `WAFCDN_DATA_DIR`（缓存 `$WAFCDN_DATA_DIR/proxy`，静态站 `$WAFCDN_DATA_DIR/static`）

## openresty 说明

- openresty生命周期[流程图](https://raw.githubusercontent.com/openresty/lua-nginx-module/refs/heads/master/doc/images/lua_nginx_modules_directives.drawio.png)

- 快速开发调试重启`openresty -p ./ -s stop && sleep 2 && rm -f logs/error.log && openresty -p ./`


**依赖项**

> 已经将依赖项本地化 ./script/resty 目录下 以下内容只参考即可

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
