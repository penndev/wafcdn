FROM openresty/openresty


CMD ["openresty", "-p", "/app", "-g", "daemon off;"]