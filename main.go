package main

import (
	"log"
	"net/http"
	"sync"

	// "gorm.io/driver/sqlite" // 效率更高？
	"github.com/gin-gonic/gin"
	"github.com/glebarez/sqlite" // 更兼容
	"gorm.io/gorm"
)

func main() {
	initData()
	initTask()
	initServe()
}

// ================================================ 处理web交互
func initServe() {
	route := gin.Default()
	route.GET("/getdomaininfo", func(c *gin.Context) {
		c.String(200, `{
			"identity": "127.0.0.1",
			"back": {
				"url": "http://192.168.7.11",
				"host": "www.baidu.com",
				"header": [
					{ "header_name": "X-MY-NAME", "header_value": "penndev" }
				]
			},
			"cache": [
				{ "cache_key": "^/cc", "cache_time": 2000 }
			],
			"limit": {
				"status": 1,
				"qps": 100,
				"rate": 100
			}
		}
		`)
	})
	route.POST("/cached", func(c *gin.Context) {
		cachedData := Cache{}
		err := c.ShouldBindJSON(&cachedData)
		if err == nil {
			log.Println(err)
			return
		}
		c.Status(200)
		task.Insert(cachedData)
	})
	// 启动HTTP服务器并监听本地端口8080
	err := http.ListenAndServe("127.0.0.1:8081", route)
	if err != nil {
		panic(err)
	}
}

// ======================================== 插入缓存相关
var task *Task

var taskListLen int16 = 3

type Task struct {
	sync.Mutex
	ListIndex int16
	List      []Cache
}

func (t *Task) Insert(c Cache) {
	task.Lock()
	println(task.ListIndex, cap(task.List))
	task.List[task.ListIndex] = c
	task.ListIndex++
	if task.ListIndex == taskListLen {
		task.ListIndex = 0
		tempData := task.List
		go func() {
			print("==>")
			for _, item := range tempData {
				print("<<")
				print(item.Path)
			}
		}()
	}
	task.Unlock()
}

func initTask() {
	task = &Task{
		ListIndex: 0,
		List:      make([]Cache, taskListLen),
	}
}

// ========================================== 处理数据相关
var db *gorm.DB

type Cache struct {
	SiteID   int    `gorm:"primaryKey;comment:请求网站" binding:"required"`
	Path     string `gorm:"primaryKey;comment:请求路径" binding:"required"`
	File     string `gorm:"comment:文件路径" binding:"required"`
	Size     int    `gorm:"comment:文件大小" binding:"required"`
	Accessed int64  `gorm:"comment:访问时间lru用" binding:"required"`
	Expried  int64  `gorm:"comment:过期时间" binding:"required"`
}

func initData() {
	var err error
	db, err = gorm.Open(sqlite.Open(".db"), &gorm.Config{})
	if err != nil {
		panic("创建缓存数据库失败")
	}
	db.AutoMigrate(&Cache{})
}
