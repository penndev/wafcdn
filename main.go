package main

import (
	"crypto/md5"
	"encoding/json"
	"net/http"
	"os"
	"time"

	// "gorm.io/driver/sqlite"
	"github.com/gin-gonic/gin"
	"github.com/glebarez/sqlite" // 更兼容
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
		URL    string `json:"url"`
		Host   string `json:"host"`
		Header []struct {
			Name  string `json:"name"`
			Value string `json:"value"`
		} `json:"header"`
	} `json:"backend"`
	Cache []struct {
		Path string `json:"paht"` // 注意这里是 "path" 而不是 "paht"
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
type Cache struct {
	SiteID   int    `gorm:"primaryKey;comment:请求网站" binding:"required"`
	Path     string `gorm:"primaryKey;comment:请求路径" binding:"required"`
	File     string `gorm:"comment:文件路径" binding:"required"`
	Size     int    `gorm:"comment:文件大小" binding:"required"`
	Accessed int64  `gorm:"comment:访问时间lru用" binding:"required"`
	Expried  int64  `gorm:"comment:过期时间" binding:"required"`
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
			time.Sleep(30 * time.Second)
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
func handleSetCache(c *gin.Context) {

}

func initListenServe(addr string) {
	route := gin.Default()
	socks := route.Group("/socket")
	{
		socks.GET("/ssl", handleGetSSL)       // 获取证书
		socks.GET("/domain", handleGetDomain) // 获取域名
	}

	err := http.ListenAndServe(addr, route)
	if err != nil {
		panic(err)
	}
}

func main() {
	initDomainConfig(".domain")
	initCacheData(".cache")
	initListenServe("127.0.0.1:8081")
}
