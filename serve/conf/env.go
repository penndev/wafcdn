package conf

import (
	"os"

	"github.com/joho/godotenv"
)

func LoadEnv(f string) {
	if f == "" {
		f = ".env"
	}
	err := godotenv.Load(f)
	if err != nil {
		panic(err)
	}
	if os.Getenv("CACHE_DIR") == "" {
		panic("cant get CACHE_DIR env")
	}
}
