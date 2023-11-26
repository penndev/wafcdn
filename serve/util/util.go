package util

import (
	"fmt"
	"log"
	"os"
	"time"

	"github.com/penndev/wafcdn/serve/conf"
	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/net"
)

func DiskUsePercent() int {
	df, err := disk.Usage(conf.CacheDir)
	if err != nil {
		log.Println(err)
	}
	return int(df.UsedPercent)
}

var NetTrafficSend int
var NetTrafficRecv int

func InitNetTraffic() {
	_, err := net.IOCounters(false)
	if err != nil {
		panic(err)
	}
	var lastSend uint64
	var lastRecv uint64
	go func() {
		ticker := time.NewTicker(time.Second)
		for range ticker.C {
			// 获取所有网络接口的输入和输出计数器信息
			counters, err := net.IOCounters(false)
			if err != nil {
				log.Println(err)
				NetTrafficSend, NetTrafficRecv, lastSend, lastRecv = 0, 0, 0, 0
				continue
			}
			// 遍历每个网络接口并计算流量变化
			for _, counter := range counters {
				NetTrafficSend = int(counter.BytesSent - lastSend)
				NetTrafficRecv = int(counter.BytesRecv - lastRecv)
				lastSend = counter.BytesSent
				lastRecv = counter.BytesRecv
			}
		}
	}()
}

func MkdirLogDir(logDir string) {
	if _, err := os.Stat(logDir); os.IsNotExist(err) {
		err := os.MkdirAll(logDir, 0755)
		if err != nil {
			panic(err)
		}
		fmt.Println("Directory created successfully")
	} else if err != nil {
		panic(err)
	}
}
