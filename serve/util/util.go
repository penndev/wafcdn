package util

import (
	"log"
	"os"

	"github.com/shirou/gopsutil/v3/disk"
)

func DiskUsePercent() int {
	df, err := disk.Usage(os.Getenv("CACHE_DIR"))
	if err != nil {
		log.Println(err)
	}
	return int(df.UsedPercent)
}
