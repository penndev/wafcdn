package conf

import (
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
}
