package util

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"

	"github.com/penndev/wafcdn/serve/conf"
)

func genNginxConfFile() {
	ncdb, err := os.ReadFile("conf/nginx.conf.default")
	if err != nil {
		panic(err)
	}
	nc := string(ncdb)
	if runtime.GOOS != "windows" {
		nc = strings.ReplaceAll(nc, "#!windows ", "")
	}
	if os.Getenv("MODE") == "dev" {
		nc = strings.ReplaceAll(nc, "$wafcdn_error_level", "info")
	} else {
		nc = strings.ReplaceAll(nc, "$wafcdn_error_level", "error")
	}
	// 处理动态监听端口。
	hp, hps := conf.GetDomainPorts()
	nclh, nclhs := "", ""
	for _, v := range hp {
		fmt.Println("Openresty Listen http:", v)
		nclh += "listen " + strconv.Itoa(v) + "; "
	}
	for _, v := range hps {
		fmt.Println("Openresty Listen https:", v)
		nclhs += "listen " + strconv.Itoa(v) + " ssl http2; "
	}
	nc = strings.Replace(nc, "$wafcdn_listen_http;", nclh, 1)
	nc = strings.Replace(nc, "$wafcdn_listen_https;", nclhs, 1)

	ncf, err := os.Create("conf/nginx.conf")
	if err != nil {
		panic(err)
	}
	if _, err = ncf.WriteString(nc); err != nil {
		panic(err)
	}
	if err = ncf.Close(); err != nil {
		panic(err)
	}
}

func StartNginx() {
	// 生成nginx配置文件。
	genNginxConfFile()

	var err error
	var cmd *exec.Cmd
	_, err = os.Stat("logs/nginx.pid")
	if err == nil {
		cmd = exec.Command("nginx", "-p", "./", "-s", "reload")
	} else if os.IsNotExist(err) {
		cmd = exec.Command("nginx", "-p", "./")
	} else {
		panic(err)
	}
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err = cmd.Start()
	fmt.Println("Openresty starting")
	if err != nil {
		panic(err)
	}
}
