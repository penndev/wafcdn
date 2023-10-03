package util

import (
	"log"
	"os"
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
		log.Println("http-", v)
		nclh += "listen " + strconv.Itoa(v) + "; "
	}
	for _, v := range hps {
		log.Println("https-", v)
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
	genNginxConfFile()
	// // 设置启动参数
	// nginxArgs := []string{
	// 	"-c", "C:\\path\\to\\nginx\\nginx.conf",
	// }

	// // 创建一个执行 Nginx 命令的命令对象

	// // 设置命令的环境变量（可选）
	// cmd.Env = os.Environ()
	// currentDirectory, err := os.Getwd()
	// if err != nil {
	// 	panic(err)
	// }
	// log.Println(currentDirectory)
	// cmd := exec.Command("nginx", "-p "+currentDirectory)
	// // 设置命令的环境变量（可选）
	// // cmd.Env = os.Environ()

	// // 启动 Nginx
	// err = cmd.Start()
	// if err != nil {
	// 	fmt.Printf("启动 Nginx 出错：%v\n", err)
	// 	return
	// }

	// // 等待 Nginx 进程退出
	// err = cmd.Wait()
	// if err != nil {
	// 	fmt.Printf("Nginx 进程退出出错：%v\n", err)
	// 	return
	// }

	// fmt.Println("Nginx 进程已退出")

}
