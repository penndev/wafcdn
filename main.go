package main

import (
	"net/http"

	// "gorm.io/driver/sqlite" // 效率更高？
	"github.com/glebarez/sqlite" // 更兼容
	"gorm.io/gorm"
)

type Cache struct {
	Path     string `gorm:"primaryKey;comment:文件存储路径"`
	Size     int    `gorm:"comment:文件大小"`
	SiteID   int    `gorm:"comment:所属网站"`
	Accessed int64  `gorm:"comment:访问时间lru用"`
	Expried  int64  `gorm:"comment:过期时间"`
}

var db *gorm.DB
var err error

func initData() {
	// 创建数据库
	db, err = gorm.Open(sqlite.Open(".data"), &gorm.Config{})
	if err != nil {
		panic("创建缓存数据库失败")
	}
	db.AutoMigrate(&Cache{})
}

func initServe() {

	http.HandleFunc("/cached", func(w http.ResponseWriter, r *http.Request) {
		r.PostForm.Get("siteID")
		r.PostForm.Get("siteID")
	})

	// 启动HTTP服务器并监听本地端口8080
	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		panic(err)
	}
}

func main() {
	initData()
	initServe()
}
