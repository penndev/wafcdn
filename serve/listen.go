package serve

import (
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/penndev/wafcdn/serve/api"
	"github.com/penndev/wafcdn/serve/socket"
)

func Listen() {
	addr := os.Getenv("LISTEN")
	if addr == "" {
		panic("Cant get env LISTEN")
	}
	if os.Getenv("MODE") != "dev" {
		gin.SetMode(gin.ReleaseMode)
	}
	// 记录日志与错误恢复。
	r := gin.New()
	if gin.Mode() == gin.ReleaseMode { //正式环境。
		logFile, err := os.OpenFile("logs/gin.log", os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
		if err != nil {
			panic(err)
		}
		gin.DefaultErrorWriter = logFile
		r.Use(gin.Recovery())

		logServe, err := os.OpenFile("logs/serve.log", os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
		if err != nil {
			panic(err)
		}
		log.SetOutput(logServe)
	} else {
		r.Use(gin.Logger(), gin.Recovery())
	}
	socket.Route(r)
	api.Route(r)
	fmt.Println("WafCdn Manage Listening:", addr)
	if err := http.ListenAndServe(addr, r); err != nil {
		panic(err)
	}
}
