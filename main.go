package main

import (
	"crypto/md5"
	"encoding/json"
	"log"
	"os"
	"time"
)

var DomainVersion struct {
	Version [16]byte
	ModTime time.Time
}

var DomainConfig []struct {
	Domain string `json:"domain"`
	Port   int    `json:"port"`
	SSL    struct {
		Port int    `json:"port"`
		Crt  string `json:"crt"`
		Key  string `json:"key"`
	} `json:"ssl"`
	Identity string `json:"identity"`
	Backend  struct {
		URL    string `json:"url"`
		Host   string `json:"host"`
		Header []struct {
			Name  string `json:"name"`
			Value string `json:"value"`
		} `json:"header"`
	} `json:"backend"`
	Cache []struct {
		Path string `json:"paht"` // 注意这里是 "path" 而不是 "paht"
		Time int    `json:"time"`
	} `json:"cache"`
}

func main() {
	domainByte, err := os.ReadFile(".domain")
	if err != nil {
		panic(err)
	}
	domainStat, err := os.Stat(".domain")
	if err != nil {
		panic(err)
	}
	DomainVersion.ModTime = domainStat.ModTime()
	DomainVersion.Version = md5.Sum(domainByte)
	if err := json.Unmarshal(domainByte, &DomainConfig); err != nil {
		panic(err)
	}
	log.Println(DomainConfig)
}
