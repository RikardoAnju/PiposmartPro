package utils

import (
	"bytes"
	"fmt"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"strings"

	"github.com/aliyun/aliyun-oss-go-sdk/oss"
)

const (
	defaultOSSBucket   = "piposmart-pro-data"
	defaultOSSEndpoint = "https://oss-ap-southeast-3.aliyuncs.com"
)

func SaveUploadBytes(objectKey string, data []byte, contentType string) (string, error) {
	cleanKey := strings.Trim(path.Clean(strings.TrimPrefix(objectKey, "/")), ".")
	cleanKey = strings.TrimPrefix(cleanKey, "/")
	if cleanKey == "" {
		return "", fmt.Errorf("path upload tidak valid")
	}

	driver := strings.ToLower(strings.TrimSpace(getUploadEnv("STORAGE_DRIVER", getUploadEnv("UPLOAD_STORAGE", "local"))))
	if driver == "oss" || driver == "aliyun_oss" || driver == "alibaba_oss" {
		return saveUploadBytesToOSS(cleanKey, data, contentType)
	}

	return saveUploadBytesLocal(cleanKey, data)
}

func saveUploadBytesLocal(objectKey string, data []byte) (string, error) {
	fullPath := filepath.Join("uploads", filepath.FromSlash(objectKey))
	if err := os.MkdirAll(filepath.Dir(fullPath), 0755); err != nil {
		return "", fmt.Errorf("gagal membuat folder upload")
	}
	if err := os.WriteFile(fullPath, data, 0644); err != nil {
		return "", fmt.Errorf("gagal menyimpan file")
	}
	return "/" + filepath.ToSlash(fullPath), nil
}

func saveUploadBytesToOSS(objectKey string, data []byte, contentType string) (string, error) {
	endpoint := strings.TrimSpace(getUploadEnv("OSS_ENDPOINT", defaultOSSEndpoint))
	bucketName := strings.TrimSpace(getUploadEnv("OSS_BUCKET", defaultOSSBucket))
	accessKeyID := strings.TrimSpace(getUploadEnv("OSS_ACCESS_KEY_ID", ""))
	accessKeySecret := strings.TrimSpace(getUploadEnv("OSS_ACCESS_KEY_SECRET", ""))
	prefix := strings.Trim(getUploadEnv("OSS_PREFIX", "uploads"), "/")

	if endpoint == "" || bucketName == "" || accessKeyID == "" || accessKeySecret == "" {
		return "", fmt.Errorf("konfigurasi OSS belum lengkap")
	}

	key := objectKey
	if prefix != "" {
		key = path.Join(prefix, objectKey)
	}

	client, err := oss.New(endpoint, accessKeyID, accessKeySecret)
	if err != nil {
		return "", fmt.Errorf("gagal inisialisasi OSS")
	}

	bucket, err := client.Bucket(bucketName)
	if err != nil {
		return "", fmt.Errorf("gagal membuka bucket OSS")
	}

	options := []oss.Option{oss.ObjectACL(resolveOSSObjectACL())}
	if contentType != "" {
		options = append(options, oss.ContentType(contentType))
	}

	if err := bucket.PutObject(key, bytes.NewReader(data), options...); err != nil {
		return "", fmt.Errorf("gagal upload file ke OSS")
	}

	return buildOSSPublicURL(endpoint, bucketName, key), nil
}

func buildOSSPublicURL(endpoint, bucketName, objectKey string) string {
	if base := strings.TrimRight(strings.TrimSpace(getUploadEnv("OSS_PUBLIC_BASE_URL", "")), "/"); base != "" {
		return base + "/" + objectKey
	}

	parsed, err := url.Parse(endpoint)
	if err != nil || parsed.Host == "" {
		return strings.TrimRight(endpoint, "/") + "/" + objectKey
	}

	return parsed.Scheme + "://" + bucketName + "." + parsed.Host + "/" + objectKey
}

func getUploadEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}

func resolveOSSObjectACL() oss.ACLType {
	switch strings.ToLower(strings.TrimSpace(getUploadEnv("OSS_OBJECT_ACL", "public-read"))) {
	case "private":
		return oss.ACLPrivate
	case "default":
		return oss.ACLDefault
	default:
		return oss.ACLPublicRead
	}
}
