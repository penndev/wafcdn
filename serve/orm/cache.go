package orm

import (
	"log"
	"os"
	"strconv"
	"sync"
	"time"

	"github.com/glebarez/sqlite"
	"github.com/penndev/wafcdn/serve/util"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB

type CacheUp struct {
	File     string `gorm:"primarykey;comment:文件路径" binding:"required"`
	Accessed int64  `gorm:"comment:访问时间lru用" binding:"required"`
}
type Cache struct {
	CacheUp
	SiteID    string    `gorm:"comment:网站标识" binding:"required"`
	Path      string    `gorm:"comment:请求路径" binding:"required"`
	Size      int64     `gorm:"comment:文件大小"`
	Expried   int64     `gorm:"comment:过期时间" binding:"required"`
	CreatedAt time.Time `gorm:"index"`
}

func LoadCache(db string) {
	var gormConfig = &gorm.Config{}
	if os.Getenv("MODE") != "dev" {
		logFile, err := os.OpenFile("logs/gorm.log", os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
		if err != nil {
			panic(err)
		}
		gormConfig.Logger = logger.New(log.New(logFile, "\r\n", log.LstdFlags), logger.Config{
			SlowThreshold:             500 * time.Millisecond,
			LogLevel:                  logger.Warn,
			IgnoreRecordNotFoundError: false,
			Colorful:                  true,
		})
	}

	var err error
	DB, err = gorm.Open(sqlite.Open(db), gormConfig)
	if err != nil {
		panic(err)
	}
	err = DB.AutoMigrate(&Cache{})
	if err != nil {
		panic(err)
	}
}

// 处理批量任务队列
var cacheTask struct {
	sync.Mutex
	Cache   map[string]*Cache
	CacheUp map[string]*CacheUp
}

func InCacheDo(c *Cache) {
	cacheTask.Lock()
	defer cacheTask.Unlock()
	cacheTask.Cache[c.File] = c
}

func InCacheUp(c *CacheUp) {
	cacheTask.Lock()
	defer cacheTask.Unlock()
	if item, ok := cacheTask.Cache[c.File]; ok {
		item.Accessed = c.Accessed
		return
	}
	cacheTask.CacheUp[c.File] = c
}

func CacheInAndLruOutTask() {
	cacheTask.Cache = make(map[string]*Cache)
	cacheTask.CacheUp = make(map[string]*CacheUp)
	// 定时任务。
	diskLimit, err := strconv.Atoi(os.Getenv("CACHE_DISK_LIMIT"))
	if err != nil || diskLimit < 30 || diskLimit > 95 {
		panic("Env get CACHE_DISK_LIMIT err set 30 - 95 %")
	}
	taskCycle, err := strconv.Atoi(os.Getenv("CACHE_TASK_CYCLE"))
	if err != nil || taskCycle < 30 || taskCycle > 300 {
		panic("Env get CACHE_TASK_CYCLE err set 30-300 secend")
	}
	// 应该这里for 然后 recovery 错误并记录日志。
	go handleLru(taskCycle, diskLimit)
}

func handleLru(taskCycle, diskLimit int) {
	cycle := time.Duration(taskCycle) * time.Second
	ticker := time.NewTicker(cycle)
	for range ticker.C {
		next := time.Now().Add(cycle * 2).Unix()
		// 快速的处理数据。
		cacheTask.Lock()
		actionCache := cacheTask.Cache
		actionCacheUp := cacheTask.CacheUp
		cacheTask.Cache = make(map[string]*Cache)
		cacheTask.CacheUp = make(map[string]*CacheUp)
		cacheTask.Unlock()
		// 开始事务处理
		tx := DB.Begin()
		if tx.Error != nil {
			log.Println("事务开始失败:", tx.Error)
			continue
		}
		// 插入数据，已存在则更新。
		insertNum, updateNum, expriedNum, lruNum := 0, 0, 0, 0
		for _, cache := range actionCache {
			if err := tx.Create(cache).Error; err != nil {
				tx.Updates(cache)
			}
			insertNum += 1
		}
		// 处理lru信息。
		for _, cacheup := range actionCacheUp {
			tx.Model(&Cache{}).Where("file = ?", cacheup.File).Update("accessed", cacheup.Accessed)
			updateNum += 1
		}
		if tx.Commit(); tx.Error != nil {
			log.Println("事务提交失败:", tx.Error)
			continue
		}
		// 删除lru数据。
		for next >= time.Now().Unix() {
			// 是否需要出栈
			if util.DiskUsePercent() > diskLimit {
				// 删除过期的文件
				var exprieds []string
				DB.Model(&Cache{}).Select("File").Where("Expried < ?", next).Order("Expried ASC").Limit(1000).Pluck("File", &exprieds)
				DB.Delete(&Cache{}, exprieds)
				for _, f := range exprieds {
					expriedNum += 1
					os.Remove(f)
				}
				// lru 删除未过期的文件
				var accesseds []string
				DB.Model(&Cache{}).Select("File").Order("Accessed ASC").Limit(1000).Pluck("File", &accesseds)
				DB.Delete(&Cache{}, accesseds)
				for _, f := range accesseds {
					lruNum += 1
					os.Remove(f)
				}
				continue
			} else {
				break
			}
		}
		log.Printf("handleLru insert[%d] update[%d] expried[%d] lru[%d] time[%d]", insertNum, updateNum, expriedNum, lruNum, next-time.Now().Unix())
	}
}

// 获取缓存数据统计。
func CacheTotalandToday() (int64, int64) {
	var total int64
	DB.Model(&Cache{}).Count(&total)
	var today int64
	DB.Model(&Cache{}).Where("created_at > ?", time.Now().Format("2006-01-02 00:00:00")).Count(&today)
	return total, today
}
