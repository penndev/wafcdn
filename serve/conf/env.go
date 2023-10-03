package conf

import (
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

var CacheDir string

var DocacheLimitStart int

var DocacheLimitCount int

func LoadEnv(f string) {
	if f == "" {
		f = ".env"
	}
	err := godotenv.Load(f)
	if err != nil {
		panic(err)
	}
	// 缓存文件的目录
	if os.Getenv("CACHE_DIR") == "" {
		panic("cant get CACHE_DIR env")
	}
	CacheDir = os.Getenv("CACHE_DIR")

	// 缓存速率，cdn防止快进快出降低硬盘寿命。
	docacheLimitStart, err := strconv.Atoi(os.Getenv("DOCACHE_LIMIT_STSRT"))
	if err != nil || docacheLimitStart < 5 || docacheLimitStart > 95 {
		panic("Env get DOCACHE_LIMIT_STSRT err set 5 - 95 %")
	}
	docacheLimitCount, err := strconv.Atoi(os.Getenv("DOCACHE_LIMIT_COUNT"))
	if err != nil || docacheLimitCount < 1 || docacheLimitCount > 10 {
		panic("Env get DOCACHE_LIMIT_COUNT err set 1 - 10")
	}
	DocacheLimitStart = docacheLimitStart
	DocacheLimitCount = docacheLimitCount

}
