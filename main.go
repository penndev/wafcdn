package main

import (
	"crypto/md5"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strconv"
	"sync"
	"time"

	// "gorm.io/driver/sqlite"
	"github.com/gin-gonic/gin"
	"github.com/glebarez/sqlite" // 更兼容
	"github.com/joho/godotenv"
	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/mem"
	"github.com/shirou/gopsutil/v3/net"
	"gorm.io/gorm"
)

// - 域名配置类文件
// -
type DomainInfo struct {
	Domain string `json:"domain"`
	Port   int    `json:"port"`
	SSL    struct {
		Port int    `json:"port"`
		Crt  string `json:"crt"`
		Key  string `json:"key"`
	} `json:"ssl"`
	Identity string `json:"identity"`
	Backend  struct {
		URL       string `json:"url"`
		Host      string `json:"host"`
		ReqHeader []struct {
			Name  string `json:"name"`
			Value string `json:"value"`
		} `json:"req_header"`
		RespHeader []struct {
			Name  string `json:"name"`
			Value string `json:"value"`
		} `json:"resp_header"`
	} `json:"backend"`
	Cache []struct {
		Path string `json:"path"` // 注意这里是 "path" 而不是 "paht"
		Time int    `json:"time"`
	} `json:"cache"`
}

var DomainInfoMap = make(map[string]DomainInfo)

var DomainVersion struct {
	Version [16]byte
	ModTime time.Time
}

func initDomainConfig(domainFile string) {
	domainByte, err := os.ReadFile(domainFile)
	if err != nil {
		panic(err)
	}
	var domainConfigs []DomainInfo
	if err := json.Unmarshal(domainByte, &domainConfigs); err != nil {
		panic(err)
	}
	for _, domaininfo := range domainConfigs {
		DomainInfoMap[domaininfo.Domain] = domaininfo
	}
	domainStat, err := os.Stat(domainFile)
	if err != nil {
		panic(err)
	}
	DomainVersion.ModTime = domainStat.ModTime()
	DomainVersion.Version = md5.Sum(domainByte)
}

// - 缓存文件数据库
// -
type CacheUp struct {
	File     string `gorm:"primarykey;comment:文件路径" binding:"required"`
	Accessed int64  `gorm:"comment:访问时间lru用" binding:"required"`
}
type Cache struct {
	CacheUp
	SiteID    string `gorm:"comment:网站标识" binding:"required"`
	Path      string `gorm:"comment:请求路径" binding:"required"`
	Size      int    `gorm:"comment:文件大小"`
	Expried   int64  `gorm:"comment:过期时间" binding:"required"`
	CreatedAt time.Time
}

var CacheData *gorm.DB

func initCacheData(db string) {
	var err error
	CacheData, err = gorm.Open(sqlite.Open(db), &gorm.Config{})
	if err != nil {
		panic("创建缓存数据库失败")
	}
	CacheData.AutoMigrate(&Cache{})
}

// 处理任务队列
type CacheTask struct {
	mu      sync.Mutex
	CacheUp map[string]*CacheUp
	Cache   map[string]*Cache
}

func (t *CacheTask) InsertCache(c *Cache) {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.Cache[c.File] = c
}

func (t *CacheTask) InsertCacheUp(c *CacheUp) {
	t.mu.Lock()
	defer t.mu.Unlock()
	if item, ok := t.Cache[c.File]; ok {
		item.Accessed = c.Accessed
		return
	}
	t.CacheUp[c.File] = c
}

var cacheTask = CacheTask{
	CacheUp: make(map[string]*CacheUp),
	Cache:   make(map[string]*Cache),
}

func initCacheTask() {
	diskLimit, err := strconv.Atoi(os.Getenv("CACHE_DISK_LIMIT"))
	if err != nil || diskLimit < 30 || diskLimit > 95 {
		panic("Env get CACHE_DISK_LIMIT err set 30 - 95 %")
	}
	taskCycle, err := strconv.Atoi(os.Getenv("CACHE_TASK_CYCLE"))
	if err != nil || taskCycle < 30 || taskCycle > 300 {
		panic("Env get CACHE_TASK_CYCLE err set 30-300 secend")
	}
	go func() {
		cycle := time.Duration(taskCycle) * time.Second
		ticker := time.NewTicker(cycle)
		for range ticker.C {
			next := time.Now().Add(cycle * 2).Unix()
			// 提交数据更改。
			cacheTask.mu.Lock()
			actionCache := cacheTask.Cache
			actionCacheUp := cacheTask.CacheUp
			cacheTask.Cache = make(map[string]*Cache)
			cacheTask.CacheUp = make(map[string]*CacheUp)
			cacheTask.mu.Unlock()
			//
			tx := CacheData.Begin()
			if tx.Error != nil {
				log.Println("事务开始失败:", tx.Error)
				continue
			}
			for _, cache := range actionCache {
				tx.Create(cache)
			}
			for file, cacheup := range actionCacheUp {
				where := &Cache{}
				where.File = file
				update := Cache{}
				update.Accessed = cacheup.Accessed
				tx.Where(where).Updates(update)
			}
			tx.Commit()
			if tx.Error != nil {
				log.Println("事务提交失败:", tx.Error)
				continue
			}
			for next >= time.Now().Unix() {
				// 检查硬盘空间
				df, err := disk.Usage(os.Getenv("CACHE_DIR"))
				if err != nil {
					panic(err)
				}
				if int(df.UsedPercent) > diskLimit {
					// "删除过期的文件，
					var exprieds []string
					CacheData.Model(&Cache{}).Select("File").Where("Expried < ?", next).Order("Expried ASC").Limit(1000).Pluck("File", &exprieds)
					CacheData.Delete(&Cache{}, exprieds)
					for _, f := range exprieds {
						os.Remove(f)
					}

					// lru删除缓存"
					var accesseds []string
					CacheData.Model(&Cache{}).Select("File").Order("Accessed ASC").Limit(1000).Pluck("File", &accesseds)
					CacheData.Delete(&Cache{}, accesseds)
					for _, f := range accesseds {
						os.Remove(f)
					}
					continue
				} else {
					log.Println("硬盘使用进度", df.UsedPercent, next-time.Now().Unix())
					break
				}
			}
		}
	}()

}

var netTrafficSend int
var netTrafficRecv int

func initNetTraffic() {
	_, err := net.IOCounters(false)
	if err != nil {
		panic(err)
	}
	var lastSend uint64
	var lastRecv uint64
	go func() {
		for {
			// 获取所有网络接口的输入和输出计数器信息
			counters, _ := net.IOCounters(false)
			// 遍历每个网络接口并计算流量变化
			for _, counter := range counters {
				netTrafficSend = int(counter.BytesSent - lastSend)
				netTrafficRecv = int(counter.BytesRecv - lastRecv)
				lastSend = counter.BytesSent
				lastRecv = counter.BytesRecv
			}
			time.Sleep(1 * time.Second)
		}
	}()
}

// 对nginx提供接口
// -
func handleGetSSL(c *gin.Context) {
	host := c.Query("host")
	if host != "" {
		if item, ok := DomainInfoMap[host]; ok {
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
func handleGetDomain(c *gin.Context) {
	host := c.Query("host")
	if host != "" {
		if item, ok := DomainInfoMap[host]; ok {
			c.JSON(200, gin.H{
				"identity": item.Identity,
				"backend":  item.Backend,
				"cache":    item.Cache,
			})
			return
		}
	}
	c.Status(400)
}
func handleDoCache(c *gin.Context) {
	cache := Cache{}
	err := c.ShouldBindJSON(&cache)
	if err != nil {
		log.Println(err)
		c.Status(400)
		return
	}
	cacheTask.InsertCache(&cache)
	c.Status(200)
}
func handleUpCache(c *gin.Context) {
	cacheUp := CacheUp{}
	err := c.ShouldBindJSON(&cacheUp)
	if err != nil {
		log.Println(err)
		c.Status(400)
		return
	}
	cacheTask.InsertCacheUp(&cacheUp)
	c.Status(200)
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
	CacheData.Model(&Cache{}).Count(&filetotal)
	var filetoday int64
	CacheData.Model(&Cache{}).Where("created_at > ?", time.Now().Format("2006-01-02 00:00:00")).Count(&filetoday)
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
			"send": netTrafficSend,
			"recv": netTrafficRecv,
		},
	})
}
func initListenServe(addr string) {
	route := gin.Default()
	socks := route.Group("/socket")
	{
		socks.GET("/ssl", handleGetSSL)       // 获取证书
		socks.GET("/domain", handleGetDomain) // 获取域名
		socks.POST("/docache", handleDoCache)
		socks.POST("/upcache", handleUpCache)
	}

	remote := route.Group("/remote")
	{
		remote.GET("/stat", handleRemoteStat)
	}

	err := http.ListenAndServe(addr, route)
	if err != nil {
		panic(err)
	}
}

func main() {
	err := godotenv.Load()
	if err != nil {
		log.Fatal("Error loading .env file", err)
	}
	// 初始化数据
	initDomainConfig(".domain")
	initCacheData(".cache")
	// 后台定时任务
	initCacheTask()
	initNetTraffic()
	// web 接口
	gin.SetMode(os.Getenv("MODE"))
	initListenServe(os.Getenv("LISTEN"))
}
