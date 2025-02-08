package panel

import (
	"github.com/gin-gonic/gin"
)

func Listen() {
	r := gin.Default()
	r.GET("/ping", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "pong",
		})
	})
	WAFCDNRoute(r)
	r.Run("127.0.0.1:8000")
}
