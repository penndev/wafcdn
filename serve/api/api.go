package api

import (
	"encoding/hex"
	"encoding/json"
	"errors"
	"log"
	"os"
	"strings"

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
	tokenStr, err := token.SignedString([]byte(os.Getenv("KEY")))
	if err != nil {
		log.Println(err)
		c.JSON(400, gin.H{
			"message": "登录失败",
		})
		return
	}
	c.JSON(200, gin.H{
		"token":  tokenStr,
		"routes": "WafCdnStat,WafCdnDomain,WafCdnCache",
	})
}

func jwtMiddle(c *gin.Context) {
	tokenStr := c.Request.Header.Get("X-Token")
	if tokenStr == "" {
		c.JSON(401, gin.H{
			"message": "需要用户登录",
		})
		c.Abort()
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
		c.Abort()
	}
	c.Next()
}

func handleRemoteStat(c *gin.Context) {
	memory, err := mem.VirtualMemory()
	if err != nil {
		c.JSON(500, gin.H{
			"err":     err,
			"message": "cant get memory!",
		})
		return
	}
	cpuCounts, err := cpu.Counts(true)
	if err != nil {
		c.JSON(500, gin.H{
			"err":     err,
			"message": "cant get cpuPercent!",
		})
		return
	}
	cpuPercent, err := cpu.Percent(0, false)
	if err != nil {
		c.JSON(500, gin.H{
			"err":     err,
			"message": "cant get cpuPercent!",
		})
		return
	}
	diskInfo, _ := disk.Usage(conf.CacheDir)
	if err != nil {
		c.JSON(500, gin.H{
			"err":     err,
			"message": "cant get disk.Usage!",
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

func handleDomain(c *gin.Context) {
	domainMap := conf.GetDomain()
	var domainList []conf.DomainItem
	for _, item := range domainMap {
		domainList = append(domainList, item)
	}
	c.JSON(200, domainList)
}

func handleDomainUpdate(c *gin.Context) {
	var domainConfigs []conf.DomainItem
	if err := c.ShouldBindJSON(&domainConfigs); err != nil {
		c.JSON(400, gin.H{
			"message": err.Error(),
		})
		return
	}
	// 将数据编码为JSON格式
	jsonData, err := json.MarshalIndent(domainConfigs, "", "  ")
	if err != nil {
		c.JSON(400, gin.H{
			"message": err.Error(),
		})
		return
	}

	// 将JSON数据写入文件
	file, err := os.Create(conf.DomainFileName)
	if err != nil {
		c.JSON(400, gin.H{
			"message": err.Error(),
		})
		return
	}
	defer conf.LoadDomain(conf.DomainFileName)
	defer file.Close()
	_, err = file.Write(jsonData)
	if err != nil {
		c.JSON(400, gin.H{
			"message": err.Error(),
		})
		return
	}
	// 写入到文件。
	log.Println(domainConfigs)
	c.JSON(200, gin.H{
		"message": "完成",
	})
}

func handleCacheList(c *gin.Context) {
	var list []orm.Cache
	var count int64
	var param struct {
		Page  int    `form:"page" binding:"required,gte=0"`
		Limit int    `form:"limit" binding:"required,gte=20,lte=100"`
		Path  string `form:"path"`
	}
	if err := c.ShouldBindQuery(&param); err != nil {
		c.JSON(400, gin.H{
			"message": err.Error(),
		})
		return
	}
	query := orm.DB.Model(orm.Cache{})
	if param.Path != "" {
		query.Where("path like ?", param.Path+"%")
	}
	query.Count(&count)
	query.Offset((param.Page - 1) * param.Limit).Limit(param.Limit).Find(&list)
	c.JSON(200, gin.H{
		"total": count,
		"data":  list,
	})
}

func handleCacheListDelete(c *gin.Context) {
	file := c.Query("file")
	list := strings.Split(file, ",")
	var deleteFile []string
	orm.DB.Model(orm.Cache{}).Where("file in ?", list).Pluck("File", &deleteFile)
	for _, item := range deleteFile {
		os.Remove(item)
	}
	orm.DB.Delete(orm.Cache{}, deleteFile)
	c.JSON(200, gin.H{
		"message": "完成",
	})
}

func Route(route *gin.Engine) {
	socks := route.Group("/api")
	{
		socks.GET("/captcha", handleCaptcha)
		socks.POST("/login", handleLogin)
		socks.Use(jwtMiddle)
		{
			socks.GET("/stat", handleRemoteStat)
			socks.GET("/domain", handleDomain)
			socks.PUT("/domain", handleDomainUpdate)
			socks.GET("/cache", handleCacheList)
			socks.DELETE("/cache", handleCacheListDelete)
		}
	}
}
