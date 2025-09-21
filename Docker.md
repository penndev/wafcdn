# WAFCDN

## ENV列表

- DB_URL
- CACHE_URL
- APP_SECRET

## EXPOSE 端口
- 8000 管理端口
- 443 HTTPS
- 80 HTTP

## DIR

- /data 数据存储目录
- /app/logs 运行日志

## 快速运行命令

```bash
docker pull penndev/wafcdn:latest
docker run -d --network host -e APP_SECRET=secret penndev/wafcdn:latest
```


- 小并发单机部署命令
```bash
docker run -e DB_URL=sqlite://sqlite.db -e CACHE_URL=ttlmap://memory -d -p 80:80 -p 443:443 -p 8000:8000 -e APP_SECRET=secret penndev/wafcdn:latest
```

- 高并发运行
```bash
docker run -e DB_URL=postgres://postgres:123456@127.0.0.1:5432/wafcdn -e CACHE_URL=redis://default:@127.0.0.1:6379/1 -d -p 80:80 -p 443:443 -p 8000:8000 -e APP_SECRET=secret penndev/wafcdn:latest
```