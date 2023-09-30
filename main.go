package main

import (
	"github.com/penndev/wafcdn/serve"
	"github.com/penndev/wafcdn/serve/conf"
	"github.com/penndev/wafcdn/serve/orm"
)

func main() {
	conf.LoadEnv(".env")
	conf.LoadDomain(".domain")
	orm.LoadCache(".cache")
	serve.Listen()
}
