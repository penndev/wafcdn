package socket

import (
	"log"

	"github.com/gin-gonic/gin"
	"github.com/penndev/wafcdn/serve/conf"
	"github.com/penndev/wafcdn/serve/orm"
)

// 对nginx提供接口 获取域名的证书。
// @url=/socket/ssl?host=@host
// @return crt=base64(originCrt)
// @return key=base64(originKey)
func handleGetSSL(c *gin.Context) {
	host := c.Query("host")
	if host != "" {
		if item, ok := conf.GetDomainItem(host); ok {
			if item.SSL.Crt != "" && item.SSL.Key != "" {
				c.JSON(200, gin.H{
					"crt": item.SSL.Crt,
					"key": item.SSL.Key,
				})
				return
			}
		}
	}
	c.Status(400)
}

// 对nginx提供接口 获取域名配置信息
// 域名标志 缓存目录，当前缓存控制。
// @url=/socket/domain?host=@host
// @return security 安全配置
// @return backend 回源信息
// @return cache 缓存信息
func handleGetDomain(c *gin.Context) {
	host := c.Query("host")
	if host != "" {
		// 判断是否全速缓存。
		if item, ok := conf.GetDomainItem(host); ok {
			c.JSON(200, gin.H{
				"backend": item.Backend,
				"cache":   item.Cache,
			})
			return
		}
	}
	c.Status(400)
}

// 将缓存信息持久化到sqlite
// @method=post
// @url=/socket/cachedo
// @return null
func handleCacheDo(c *gin.Context) {
	cache := orm.Cache{}
	err := c.ShouldBindJSON(&cache)
	if err != nil {
		log.Println(err)
		c.Status(400)
		return
	}
	orm.InCacheDo(&cache)
	c.Status(200)
}

// 将缓存信息持久化到sqlite
// @method=post
// @url=/socket/cacheup
// @return null
func handleCacheUp(c *gin.Context) {
	cacheUp := orm.CacheUp{}
	err := c.ShouldBindJSON(&cacheUp)
	if err != nil {
		log.Println(err)
		c.Status(400)
		return
	}
	orm.InCacheUp(&cacheUp)
	c.Status(200)
}

func Route(route *gin.Engine) {
	socks := route.Group("/socket")
	{
		socks.GET("/ssl", handleGetSSL)       // 获取证书
		socks.GET("/domain", handleGetDomain) // 获取域名
		socks.POST("/cachedo", handleCacheDo)
		socks.POST("/cacheup", handleCacheUp)
	}
}
