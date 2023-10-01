package orm

import (
	"sync"
	"time"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
)

var DB *gorm.DB

type CacheUp struct {
	File     string `gorm:"primarykey;comment:文件路径" binding:"required"`
	Accessed int64  `gorm:"comment:访问时间lru用" binding:"required"`
}
type Cache struct {
	CacheUp
	SiteID    string `gorm:"comment:网站标识" binding:"required"`
	Path      string `gorm:"comment:请求路径" binding:"required"`
	Size      int64  `gorm:"comment:文件大小"`
	Expried   int64  `gorm:"comment:过期时间" binding:"required"`
	CreatedAt time.Time
}

func LoadCache(db string) {
	var err error
	DB, err = gorm.Open(sqlite.Open(db), &gorm.Config{})
	if err != nil {
		panic(err)
	}
	err = DB.AutoMigrate(&Cache{})
	if err != nil {
		panic(err)
	}
}

// 处理批量任务队列
type cacheTask struct {
	sync.RWMutex
	CacheUp map[string]*CacheUp
	Cache   map[string]*Cache
}

func InCacheDo(c *Cache) {

}

func InCacheUp(c *CacheUp) {

}

// func (t *CacheTask) InsertCache(c *Cache) {
// 	t.mu.Lock()
// 	defer t.mu.Unlock()
// 	t.Cache[c.File] = c
// }

// func (t *CacheTask) InsertCacheUp(c *CacheUp) {
// 	t.mu.Lock()
// 	defer t.mu.Unlock()
// 	if item, ok := t.Cache[c.File]; ok {
// 		item.Accessed = c.Accessed
// 		return
// 	}
// 	t.CacheUp[c.File] = c
// }

// var cacheTask = CacheTask{
// 	CacheUp: make(map[string]*CacheUp),
// 	Cache:   make(map[string]*Cache),
// }

// func initCacheTask() {
// 	diskLimit, err := strconv.Atoi(os.Getenv("CACHE_DISK_LIMIT"))
// 	if err != nil || diskLimit < 30 || diskLimit > 95 {
// 		panic("Env get CACHE_DISK_LIMIT err set 30 - 95 %")
// 	}
// 	taskCycle, err := strconv.Atoi(os.Getenv("CACHE_TASK_CYCLE"))
// 	if err != nil || taskCycle < 30 || taskCycle > 300 {
// 		panic("Env get CACHE_TASK_CYCLE err set 30-300 secend")
// 	}
// 	go func() {
// 		cycle := time.Duration(taskCycle) * time.Second
// 		ticker := time.NewTicker(cycle)
// 		for range ticker.C {
// 			next := time.Now().Add(cycle * 2).Unix()
// 			// 提交数据更改。
// 			cacheTask.mu.Lock()
// 			actionCache := cacheTask.Cache
// 			actionCacheUp := cacheTask.CacheUp
// 			cacheTask.Cache = make(map[string]*Cache)
// 			cacheTask.CacheUp = make(map[string]*CacheUp)
// 			cacheTask.mu.Unlock()
// 			//
// 			tx := CacheData.Begin()
// 			if tx.Error != nil {
// 				log.Println("事务开始失败:", tx.Error)
// 				continue
// 			}
// 			for _, cache := range actionCache {
// 				if err := tx.Create(cache).Error; err != nil {
// 					tx.Updates(cache)
// 				}
// 			}
// 			for file, cacheup := range actionCacheUp {
// 				up := &Cache{}
// 				up.File = file
// 				up.Accessed = cacheup.Accessed
// 				tx.Updates(up)
// 				// 判断是否修改成功。避免清空其他数据。
// 			}
// 			tx.Commit()
// 			if tx.Error != nil {
// 				log.Println("事务提交失败:", tx.Error)
// 				continue
// 			}
// 			for next >= time.Now().Unix() {
// 				// 检查硬盘空间
// 				df, err := disk.Usage(os.Getenv("CACHE_DIR"))
// 				if err != nil {
// 					panic(err)
// 				}
// 				if int(df.UsedPercent) > diskLimit {
// 					// "删除过期的文件，
// 					var exprieds []string
// 					CacheData.Model(&Cache{}).Select("File").Where("Expried < ?", next).Order("Expried ASC").Limit(1000).Pluck("File", &exprieds)
// 					CacheData.Delete(&Cache{}, exprieds)
// 					for _, f := range exprieds {
// 						os.Remove(f)
// 					}

// 					// lru删除缓存"
// 					var accesseds []string
// 					CacheData.Model(&Cache{}).Select("File").Order("Accessed ASC").Limit(1000).Pluck("File", &accesseds)
// 					CacheData.Delete(&Cache{}, accesseds)
// 					for _, f := range accesseds {
// 						os.Remove(f)
// 					}
// 					continue
// 				} else {
// 					log.Println("硬盘使用进度", df.UsedPercent, next-time.Now().Unix())
// 					break
// 				}
// 			}
// 		}
// 	}()
// }
