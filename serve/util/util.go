package util

import (
	"log"

	"github.com/penndev/wafcdn/serve/conf"
	"github.com/shirou/gopsutil/v3/disk"
)

func DiskUsePercent() int {
	df, err := disk.Usage(conf.CacheDir)
	if err != nil {
		log.Println(err)
	}
	return int(df.UsedPercent)
}
