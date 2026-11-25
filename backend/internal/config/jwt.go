package config

import (
	"time"
)

var (
	JWTSecret = []byte(RequiredEnv("JWT_SECRET"))
	JWTExpire = time.Hour * 24 * 7 // 7 hari
)
