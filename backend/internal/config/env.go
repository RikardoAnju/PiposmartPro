package config

import (
	"fmt"
	"log"
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	DB_DSN        string
	AppPort       string
	RedisAddr     string
	RedisUsername string
	RedisPassword string
	RedisDB       int
}

func LoadConfig() *Config {
	// Memuat file .env jika ada
	_ = godotenv.Load()

	// Ambil DB_DSN langsung dari environment
	dsn := RequiredEnv("DB_DSN")

	// Log untuk memastikan host mana yang tersambung
	log.Printf("🚀 App Started | Port: %s", GetEnv("APP_PORT", "8080"))

	// Redis DB string to int
	redisDBStr := GetEnv("REDIS_DB", "0")
	var redisDB int
	fmt.Sscanf(redisDBStr, "%d", &redisDB)

	return &Config{
		DB_DSN:        dsn,
		AppPort:       GetEnv("APP_PORT", "8080"),
		RedisAddr:     GetEnv("REDIS_ADDR", "Redis-Server:6379"),
		RedisUsername: GetEnv("REDIS_USERNAME", ""),
		RedisPassword: GetEnv("REDIS_PASSWORD", ""),
		RedisDB:       redisDB,
	}
}

func GetEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}

func RequiredEnv(key string) string {
	_ = godotenv.Load()
	value, ok := os.LookupEnv(key)
	if !ok || value == "" {
		log.Fatalf("%s environment variable is required", key)
	}
	return value
}
