package serve

import (
	"log"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
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
		logFile, err := os.Open("logs/serve_error.log")
		if err != nil {
			panic(err)
		}
		gin.DefaultErrorWriter = logFile
		// 日志文件如何处理呢？r.Use(gin.Logger())
		r.Use(gin.Recovery())
	} else {
		r.Use(gin.Logger(), gin.Recovery())
	}
	socket.Route(r)
	log.Println("Start Listening:", addr)
	http.ListenAndServe(addr, r)
}
