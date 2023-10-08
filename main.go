package main

import (
	"github.com/penndev/wafcdn/serve"
	"github.com/penndev/wafcdn/serve/conf"
	"github.com/penndev/wafcdn/serve/orm"
	"github.com/penndev/wafcdn/serve/util"
)

func main() {
	conf.LoadEnv(".env")            // 加载与校验配置
	conf.LoadDomain(".domain.json") // 加载持久域名配置信息
	orm.LoadCache(".cache.db")      // 加载持久缓存sqlite数据。
	orm.CacheInAndLruOutTask()      // 启动缓存文件入库和清理。
	util.StartNginx()               // 启动nginx(openresty)
	util.InitNetTraffic()           // 监控系统的流量
	serve.Listen()                  // http接口
}
