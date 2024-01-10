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
	nginxConfDefault, err := os.ReadFile("conf/nginx.conf.default")
	if err != nil {
		panic(err)
	}
	nginxConf := string(nginxConfDefault)
	if runtime.GOOS != "windows" {
		nginxConf = strings.ReplaceAll(nginxConf, "#!windows ", "")
	}
	if os.Getenv("MODE") == "dev" {
		nginxConf = strings.ReplaceAll(nginxConf, "$wafcdn_error_level;", "info;")
	} else {
		nginxConf = strings.ReplaceAll(nginxConf, "$wafcdn_error_level;", "error;")
	}
	// 处理env配置项。
	envPort := strings.Split(os.Getenv("LISTEN"), ":")
	if len(envPort) == 2 {
		nginxConf = strings.ReplaceAll(nginxConf, "$wafcdn_socket_api;", "http://127.0.0.1:"+envPort[1]+";")
	} else {
		panic("env LISTEN set error")
	}
	nginxConf = strings.ReplaceAll(nginxConf, "$wafcdn_cache_dir;", os.Getenv("CACHE_DIR")+";")
	// 处理动态监听端口。//如果http已经占用端口https则取消占用。
	httpPorts, httpsPorts := conf.GetDomainPorts()
	httpList, httpsList := "", ""
	for _, v := range httpPorts {
		httpSub := "listen " + strconv.Itoa(v) + "; "
		if !strings.Contains(httpList, httpSub) {
			fmt.Println("WafCdn Service add http:", v)
			httpList += httpSub
		}
	}
	for _, v := range httpsPorts {
		httpsSub := "listen " + strconv.Itoa(v) + " ssl http2; "
		httpSub := "listen " + strconv.Itoa(v) + "; "
		if !strings.Contains(httpsList, httpSub) && !strings.Contains(httpsList, httpsSub) {
			fmt.Println("WafCdn Service add https:", v)
			httpsList += httpsSub
		}
	}
	nginxConf = strings.Replace(nginxConf, "$wafcdn_listen_http;", httpList, 1)
	nginxConf = strings.Replace(nginxConf, "$wafcdn_listen_https;", httpsList, 1)
	// 生成新的配置文件。
	nginxConfFile, err := os.Create("conf/nginx.conf")
	if err != nil {
		panic(err)
	}
	if _, err = nginxConfFile.WriteString(nginxConf); err != nil {
		panic(err)
	}
	if err = nginxConfFile.Close(); err != nil {
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
		cmd := exec.Command(nginxBin, "-p", "./", "-t")
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		cmd.Start()
		fmt.Println("Pleases check nginx error: nginx -t | port use")
		panic(err)
	}
}
