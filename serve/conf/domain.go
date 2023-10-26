package conf

import (
	"crypto/md5"
	"encoding/json"
	"os"
	"time"
)

var DomainVersion struct {
	Version [16]byte
	ModTime time.Time
}

type DomainItem struct {
	Domain string `json:"domain"`
	Port   int    `json:"port"`
	SSL    struct {
		Port int    `json:"port"`
		Crt  string `json:"crt"`
		Key  string `json:"key"`
	} `json:"ssl"`
	Security struct {
		Status      bool `json:"status"`
		QPS         int  `json:"qps"`
		IPWhiteList string
		IPBlackList string
	} `json:"security"`
	Backend struct {
		URL       string `json:"url"`
		Host      string `json:"host"`
		ReqHeader []struct {
			Name  string `json:"name"`
			Value string `json:"value"`
		} `json:"req_header"`
		RespHeader []struct {
			Name  string `json:"name"`
			Value string `json:"value"`
		} `json:"resp_header"`
	} `json:"backend"`
	Cache struct {
		Dir  string `json:"dir"`
		Rule []struct {
			Path string `json:"path"` // 注意这里是 "path" 而不是 "paht"
			Time int    `json:"time"`
		} `json:"rule"`
	} `json:"cache"`
}

var domainMap map[string]DomainItem

func GetDomainItem(host string) (DomainItem, bool) {
	item, ok := domainMap[host]
	return item, ok
}

func GetDomainPorts() ([]int, []int) {
	ports := make(map[int]bool)
	httplisten := []int{80}
	httpslisten := []int{443}
	for _, val := range domainMap {
		if val.Port > 0 && !ports[val.Port] {
			httplisten = append(httplisten, val.Port)
			ports[val.Port] = true
		}
		if val.SSL.Port > 0 && !ports[val.SSL.Port] {
			httpslisten = append(httpslisten, val.SSL.Port)
			ports[val.SSL.Port] = true
		}
	}
	return httplisten, httpslisten
}

func LoadDomain(domainFile string) {
	domainByte, err := os.ReadFile(domainFile)
	if err != nil {
		panic(err)
	}
	// 如果文件不存在怎么办。?待思考
	var domainConfigs []DomainItem
	if err := json.Unmarshal(domainByte, &domainConfigs); err != nil {
		panic(err)
	}
	domainMap = make(map[string]DomainItem)
	for _, domaininfo := range domainConfigs {
		domainMap[domaininfo.Domain] = domaininfo
	}
	domainStat, err := os.Stat(domainFile)
	if err != nil {
		panic(err)
	}
	DomainVersion.ModTime = domainStat.ModTime()
	DomainVersion.Version = md5.Sum(domainByte)
}
