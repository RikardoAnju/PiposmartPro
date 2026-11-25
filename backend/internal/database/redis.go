package database

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/redis/go-redis/v9"
)

var RedisClient *redis.Client

const cacheOpTimeout = 750 * time.Millisecond

func cacheContext() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), cacheOpTimeout)
}

func InitRedis(addr, username, password string, db int) (*redis.Client, error) {
	opts := &redis.Options{
		Addr:            addr,
		Username:        username,
		Password:        password,
		DB:              db,
		Protocol:        2,
		DialTimeout:     3 * time.Second,
		ReadTimeout:     1 * time.Second,
		WriteTimeout:    1 * time.Second,
		PoolSize:        10,
		MinIdleConns:    2,
		PoolTimeout:     1 * time.Second,
		MaxRetries:      1,
		MinRetryBackoff: 500 * time.Millisecond,
		MaxRetryBackoff: 1 * time.Second,
	}

	log.Printf("🔌 [Redis] Connecting to: %s", addr)
	client := redis.NewClient(opts)

	// Test connection with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		_ = client.Close()
		RedisClient = nil
		return nil, fmt.Errorf("failed to connect to redis: %v", err)
	}

	RedisClient = client
	log.Printf("🚀 Redis Connected: %s", addr)
	return RedisClient, nil
}

// GetCache retrieves data from Redis and unmarshals it into the provided target
func GetCache(key string, target interface{}) bool {
	if RedisClient == nil {
		return false
	}

	ctx, cancel := cacheContext()
	defer cancel()

	val, err := RedisClient.Get(ctx, key).Result()
	if err != nil {
		log.Printf("🔹 [Redis] MISS: %s", key)
		return false
	}

	err = json.Unmarshal([]byte(val), target)
	if err != nil {
		log.Printf("❌ [Redis] Unmarshal Error [%s]: %v", key, err)
		return false
	}

	log.Printf("✅ [Redis] HIT: %s", key)
	return true
}

// SetCache marshals the data to JSON and stores it in Redis with a TTL
func SetCache(key string, data interface{}, expiration time.Duration) {
	if RedisClient == nil {
		return
	}

	val, err := json.Marshal(data)
	if err != nil {
		log.Printf("❌ [Redis] Marshal Error [%s]: %v", key, err)
		return
	}

	ctx, cancel := cacheContext()
	defer cancel()

	err = RedisClient.Set(ctx, key, val, expiration).Err()
	if err != nil {
		log.Printf("❌ [Redis] Set Error [%s]: %v", key, err)
	} else {
		log.Printf("💾 [Redis] SET: %s (TTL: %v)", key, expiration)
	}
}

// InvalidateCache deletes one or more keys from Redis
func InvalidateCache(keys ...string) {
	if RedisClient == nil || len(keys) == 0 {
		return
	}

	ctx, cancel := cacheContext()
	defer cancel()

	err := RedisClient.Del(ctx, keys...).Err()
	if err != nil {
		log.Printf("❌ [Redis] Delete Error: %v", err)
	} else {
		log.Printf("🗑️ [Redis] PURGE: %v", keys)
	}
}

// ClearCacheByPattern deletes keys matching a pattern (e.g., "content:banners:*")
func ClearCacheByPattern(pattern string) {
	if RedisClient == nil {
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	iter := RedisClient.Scan(ctx, 0, pattern, 0).Iterator()
	deletedCount := 0
	for iter.Next(ctx) {
		err := RedisClient.Del(ctx, iter.Val()).Err()
		if err != nil {
			log.Printf("❌ [Redis] Delete Pattern Error [%s]: %v", iter.Val(), err)
		} else {
			deletedCount++
		}
	}

	if err := iter.Err(); err != nil {
		log.Printf("❌ [Redis] Scan Error: %v", err)
	} else {
		log.Printf("🧹 [Redis] CLEAR PATTERN: %s (%d keys deleted)", pattern, deletedCount)
	}
}
