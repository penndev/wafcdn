package api

import (
	"os"

	"github.com/gin-gonic/gin"
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
	diskInfo, _ := disk.Usage(os.Getenv("CACHE_DIR"))
	if err != nil {
		c.JSON(500, gin.H{
			"err": err,
			"msg": "cant get disk.Usage!",
		})
		return
	}
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
			// "total": filetotal,
			// "today": filetoday,
		},
		"traffic": gin.H{
			// "send": netTrafficSend,
			// "recv": netTrafficRecv,
		},
	})
}

func Route(route *gin.Engine) {
	socks := route.Group("/apiv1")
	{
		socks.POST("/stat", handleRemoteStat)
	}
}
