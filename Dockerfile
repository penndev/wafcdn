FROM openresty/openresty

ENV TZ=Asia/Shanghai

WORKDIR /app

# 执行文件
COPY ./dist /app/dist
COPY ./wafcdn /app/wafcdn
COPY ./script /app/script

# OpenResty环境
COPY ./conf /app/conf

# 初始化
RUN mkdir logs
RUN mkdir data
RUN openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout ./conf/private.key -out ./conf/certificate.crt -config ./conf/ssl.conf

# 设置Env环境
# ENV APP_MODE=prod
# ENV APP_LISTEN=:8000
# 应该用户必须设置
# ENV APP_SECRET=secret
ENV APP_LOGGER_FILE=logs/app.log
ENV APP_LOGGER_LEVEL=warn
ENV DB_URL=sqlite://data/sqlite.db?_pragma=journal_mode(WAL)&_pragma=busy_timeout(3000)
ENV CACHE_URL=ttlmap://memory
# ENV NGINX_BINARY=openresty
# ENV NGINX_PREFIX=./


EXPOSE 80 443 8000

CMD ["./wafcdn"]
