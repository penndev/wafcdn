package socket

import (
	"os"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/penndev/wafcdn/serve/conf"
	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/mem"
)

// 对nginx提供接口 获取域名的证书。
// @url=/socket/ssl?host=@host
// @return base64后的nginx证书文件
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
// @return security 安全配置
// @return backend 回源信息
// @return cache 缓存信息
func handleGetDomain(c *gin.Context) {
	host := c.Query("host")
	if host != "" {
		// 判断是否全速缓存。
		df, err := disk.Usage(os.Getenv("CACHE_DIR"))
		if err != nil {
			panic(err)
		}

		docacheCount := 1
		docacheLimit, err := strconv.Atoi(os.Getenv("DOCACHE_LIMIT_STSRT"))
		if err != nil {
			panic(err)
		}
		if int(df.UsedPercent) > docacheLimit {
			docacheCount, err = strconv.Atoi(os.Getenv("DOCACHE_LIMIT_COUNT"))
			if err != nil {
				panic(err)
			}
		}

		if item, ok := conf.DomainMap[host]; ok {
			c.JSON(200, gin.H{
				"identity":     item.Identity,
				"backend":      item.Backend,
				"cache":        item.Cache,
				"docachelimit": docacheCount,
			})
			return
		}
	}
	c.Status(400)
}
func handleDoCache(c *gin.Context) {
	// cache := orm.Cache{}
	// err := c.ShouldBindJSON(&cache)
	// if err != nil {
	// 	log.Println(err)
	// 	c.Status(400)
	// 	return
	// }
	// cacheTask.InsertCache(&cache)
	// c.Status(200)
}
func handleUpCache(c *gin.Context) {
	// cacheUp := CacheUp{}
	// err := c.ShouldBindJSON(&cacheUp)
	// if err != nil {
	// 	log.Println(err)
	// 	c.Status(400)
	// 	return
	// }
	// cacheTask.InsertCacheUp(&cacheUp)
	// c.Status(200)
}
func handleRemoteStat(c *gin.Context) {
	memory, err := mem.VirtualMemory()
	if err != nil {
		c.JSON(500, gin.H{
			"err": err,
			"msg": "cant get memory!",
		})
		return
	}
	cpuCounts, err := cpu.Counts(true)
	if err != nil {
		c.JSON(500, gin.H{
			"err": err,
			"msg": "cant get cpuPercent!",
		})
		return
	}
	cpuPercent, err := cpu.Percent(0, false)
	if err != nil {
		c.JSON(500, gin.H{
			"err": err,
			"msg": "cant get cpuPercent!",
		})
		return
	}
	diskInfo, _ := disk.Usage(os.Getenv("CACHE_DIR"))
	if err != nil {
		c.JSON(500, gin.H{
			"err": err,
			"msg": "cant get disk.Usage!",
		})
		return
	}
	var filetotal int64
	// CacheData.Model(&Cache{}).Count(&filetotal)
	var filetoday int64
	// CacheData.Model(&Cache{}).Where("created_at > ?", time.Now().Format("2006-01-02 00:00:00")).Count(&filetoday)
	c.JSON(200, gin.H{
		"memory": gin.H{
			"total": memory.Total,
			"used":  memory.Used,
		},
		"cpu": gin.H{
			"percent": cpuPercent[0],
			"count":   cpuCounts,
		},
		"disk": gin.H{
			"total": diskInfo.Total,
			"used":  diskInfo.Used,
		},
		"file": gin.H{
			"total": filetotal,
			"today": filetoday,
		},
		"traffic": gin.H{
			// "send": netTrafficSend,
			// "recv": netTrafficRecv,
		},
	})
}

func Route(route *gin.Engine) {
	socks := route.Group("/socket")
	{
		socks.GET("/ssl", handleGetSSL)       // 获取证书
		socks.GET("/domain", handleGetDomain) // 获取域名
		socks.POST("/docache", handleDoCache)
		socks.POST("/upcache", handleUpCache)
	}

	// remote := route.Group("/remote")
	// {
	// 	remote.GET("/stat", handleRemoteStat)
	// }
}
