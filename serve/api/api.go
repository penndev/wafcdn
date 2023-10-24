package api

import (
	"encoding/hex"
	"errors"
	"log"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/penndev/gopkg/captcha"
	"github.com/penndev/wafcdn/serve/conf"
	"github.com/penndev/wafcdn/serve/orm"
	"github.com/penndev/wafcdn/serve/util"
	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/mem"
)

func handleCaptcha(c *gin.Context) {
	if vd, err := captcha.NewImg(); err == nil {
		c.JSON(200, gin.H{
			"captchaID":  vd.ID,
			"captchaURL": vd.PngBase64,
		})
	} else {
		c.JSON(400, gin.H{
			"message": "获取验证码失败！",
		})
	}
}

func handleLogin(c *gin.Context) {
	var json struct {
		CaptchaID string `json:"captchaID" binding:"required"`
		Captcha   string `json:"captcha" binding:"required"`
		Username  string `json:"username" binding:"required"`
		Password  string `json:"password" binding:"required"`
	}
	if c.ShouldBindJSON(&json) != nil {
		c.JSON(400, gin.H{
			"message": "接收参数错误",
		})
		return
	}
	if !captcha.Verify(json.CaptchaID, json.Captcha) {
		c.JSON(400, gin.H{
			"message": "验证码错误",
		})
		return
	}
	if json.Username != "wafcdn" || json.Password != os.Getenv("KEY") {
		c.JSON(400, gin.H{
			"message": "账号密码错误",
		})
		return
	}
	token := jwt.New(jwt.SigningMethodHS256)
	tokenstr, err := token.SignedString([]byte(os.Getenv("KEY")))
	if err != nil {
		log.Println(err)
		c.JSON(400, gin.H{
			"message": "登录失败",
		})
		return
	}
	c.JSON(200, gin.H{
		"token":  tokenstr,
		"index":  "/wafcdn/stat",
		"routes": "WafCdnStat",
	})

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
	diskInfo, _ := disk.Usage(conf.CacheDir)
	if err != nil {
		c.JSON(500, gin.H{
			"err": err,
			"msg": "cant get disk.Usage!",
		})
		return
	}
	total, today := orm.CacheTotalandToday()
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
			"total": total,
			"today": today,
		},
		"traffic": gin.H{
			"send": util.NetTrafficSend,
			"recv": util.NetTrafficRecv,
		},
		"conf": gin.H{
			"version": hex.EncodeToString(conf.DomainVersion.Version[:]),
			"time":    conf.DomainVersion.ModTime.Unix(),
		},
	})
}

func Route(route *gin.Engine) {
	socks := route.Group("/apiv1")
	{
		socks.GET("/captcha", handleCaptcha)
		socks.POST("/login", handleLogin)
		socks.Use(func(c *gin.Context) {
			tokenStr := c.Request.Header.Get("X-Token")
			if tokenStr == "" {
				c.JSON(401, gin.H{
					"message": "需要用户登录",
				})
				return
			}
			token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
				if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
					return nil, errors.New("jwt验证方法错误")
				}
				return []byte(os.Getenv("KEY")), nil
			})
			if err != nil {
				log.Println(err)
			}
			if !token.Valid {
				c.JSON(401, gin.H{
					"message": "需要用户登录1",
				})
				return
			}
			c.Next()
		})
		socks.GET("/stat", handleRemoteStat)
	}
}
