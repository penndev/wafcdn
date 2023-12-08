package util

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/penndev/wafcdn/serve/conf"
)

func checkNginxStatus() bool {
	pidfile, err := os.ReadFile("logs/nginx.pid")
	if err != nil {
		return false
	}
	pid, err := strconv.Atoi(string(pidfile))
	if err != nil {
		return false
	}

	if p, err := os.FindProcess(pid); err != nil {
		return false
	} else {
		e := p.Signal(syscall.Signal(0))
		return e == nil
	}
}

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
		nc = strings.ReplaceAll(nc, "$wafcdn_error_level;", "info;")
	} else {
		nc = strings.ReplaceAll(nc, "$wafcdn_error_level;", "error;")
	}
	// 处理env配置项。
	eport := strings.Split(os.Getenv("LISTEN"), ":")
	if len(eport) == 2 {
		nc = strings.ReplaceAll(nc, "$wafcdn_socket_api;", "http://127.0.0.1:"+eport[1]+";")
	} else {
		panic("env LISTEN set error")
	}
	nc = strings.ReplaceAll(nc, "$wafcdn_cache_dir;", os.Getenv("CACHE_DIR")+";")
	// 处理动态监听端口。
	hp, hps := conf.GetDomainPorts()
	nclh, nclhs := "", ""
	for _, v := range hp {
		fmt.Println("WafCdn Service add http:", v)
		nclh += "listen " + strconv.Itoa(v) + "; "
	}
	for _, v := range hps {
		fmt.Println("WafCdn Service add https:", v)
		nclhs += "listen " + strconv.Itoa(v) + " ssl http2; "
	}
	nc = strings.Replace(nc, "$wafcdn_listen_http;", nclh, 1)
	nc = strings.Replace(nc, "$wafcdn_listen_https;", nclhs, 1)
	// 生成新的配置文件。
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
	// 获取nginx的安装路径。
	nginxBin := os.Getenv("BIN_PATH")
	if nginxBin == "" {
		panic("cant find the BIN_PATH")
	}
	// 生成nginx配置文件。
	genNginxConfFile()
	var err error
	var cmd *exec.Cmd
	_, err = os.Stat("logs/nginx.pid")
	if err == nil {
		// 进程是否真的存活。
		if checkNginxStatus() {
			cmd = exec.Command(nginxBin, "-p", "./", "-s", "reload")
		} else {
			if err := os.Remove("logs/nginx.pid"); err != nil {
				panic(err)
			}
			cmd = exec.Command(nginxBin, "-p", "./")
		}
	} else if os.IsNotExist(err) {
		cmd = exec.Command(nginxBin, "-p", "./")
	} else {
		panic(err)
	}
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err = cmd.Start()
	fmt.Println("WafCdn Service Listening ...")
	if err != nil {
		panic(err)
	}
	time.Sleep(1 * time.Second)
	// 再次判断是否存在nginx.pid
	_, err = os.Stat("logs/nginx.pid")
	if err != nil {
		panic(err)
	}
}
