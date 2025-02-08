package panel

import (
	"fmt"
	"os"

	"github.com/gin-gonic/gin"
)

// 对nginx提供接口 获取域名配置信息
// @url=/@wafcdn/domain?host=@host
// @return 配置信息
func handleDomain(c *gin.Context) {
	// 读取文件内容
	data, err := os.ReadFile("docs/domain.json")
	if err != nil {
		fmt.Println("读取文件错误:", err)
		return
	}

	c.String(200, string(data))
}

func WAFCDNRoute(route *gin.Engine) {
	r := route.Group("/@wafcdn")
	{
		r.GET("/domain", handleDomain) // 获取证书
	}
}
