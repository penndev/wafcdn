package main

import (
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

type Cache struct {
	Path     string
	Size     int
	Accessed int
	Expried  int
}

func main() {
	db, err := gorm.Open(sqlite.Open(".data"), &gorm.Config{})
	if err != nil {
		panic("创建缓存数据库失败")
	}
	db.AutoMigrate(&Cache{})

	db.Create(&Cache{
		Path: "123",
	})

}
