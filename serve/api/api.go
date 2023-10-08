package api

import (
	"github.com/gin-gonic/gin"
	"github.com/penndev/wafcdn/serve/conf"
	"github.com/penndev/wafcdn/serve/orm"
	"github.com/penndev/wafcdn/serve/util"
	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/mem"
)

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
	diskInfo, _ := disk.Usage(conf.CacheDir)
	if err != nil {
		c.JSON(500, gin.H{
			"err": err,
			"msg": "cant get disk.Usage!",
		})
		return
	}
	total, today := orm.CacheTotalandToday()
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
			"total": total,
			"today": today,
		},
		"traffic": gin.H{
			"send": util.NetTrafficSend,
			"recv": util.NetTrafficRecv,
		},
	})
}

func Route(route *gin.Engine) {
	socks := route.Group("/apiv1")
	{
		socks.Use(func(c *gin.Context) {
			c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
			c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
			c.Writer.Header().Set("Access-Control-Allow-Headers", "*")
			if c.Request.Method == "OPTIONS" {
				c.AbortWithStatus(200)
				return
			}
			c.Next()
		})
		socks.GET("/stat", handleRemoteStat)
	}
}
