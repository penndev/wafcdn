# WAFCDN

## ENV列表

- DB_URL
- CACHE_URL
- APP_SECRET JWT 签名密钥（不是登录密码，必须自行设置）
- WAFCDN_DATA_DIR
- IPREGION_DB IP 地域库文件路径（镜像内默认 `/app/ipregion.db`）

## EXPOSE 端口
- 8000 管理端口（管理端 http://127.0.0.1:8000/-admin）
- 443 HTTPS
- 80 HTTP

## DIR

- /data 数据存储目录
  - /data/sqlite.db 默认 SQLite 数据库（`DB_URL` 未覆盖时）
  - /data/proxy 反向代理缓存目录（后缀固定）
  - /data/static 静态站点文件目录（后缀固定）
- /app/logs 运行日志

## 快速运行命令

```bash
docker pull penndev/wafcdn:latest
docker run -d --network host -e APP_SECRET=secret penndev/wafcdn:latest
```

- 管理端：http://ip:8000/-admin
- 首次登录用户名填 `admin`，密码自己定；提示「已初始化管理员」后再用同一账号登录一次
- `APP_SECRET` 请换成自己的密钥


- 小并发单机部署命令
```bash
docker run -e DB_URL=sqlite:///data/sqlite.db -e CACHE_URL=ttlmap://memory -d -p 80:80 -p 443:443 -p 8000:8000 -e APP_SECRET=secret penndev/wafcdn:latest
```

- 高并发运行
```bash
docker run -e DB_URL=postgres://postgres:123456@127.0.0.1:5432/wafcdn -e CACHE_URL=redis://default:@127.0.0.1:6379/1 -d -p 80:80 -p 443:443 -p 8000:8000 -e APP_SECRET=secret penndev/wafcdn:latest
```