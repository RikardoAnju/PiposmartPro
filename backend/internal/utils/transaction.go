package utils

import (
	"fmt"
	"time"
)

func StringPtr(s string) *string {
	return &s
}

func StringValue(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func StringToInt(s string) int {
	var result int
	_, err := fmt.Sscanf(s, "%d", &result)
	if err != nil {
		return 0 // default value jika parsing gagal
	}
	return result
}

func StringToFloat64(s string) float64 {
	var result float64
	_, err := fmt.Sscanf(s, "%f", &result)
	if err != nil {
		return 0.0 // default value jika parsing gagal
	}
	return result
}

func RandomString(n int) string {
	const letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	result := make([]byte, n)
	for i := range result {
		result[i] = letters[utilsRandomInt(len(letters))]
	}
	return string(result)
}

func utilsRandomInt(max int) int {
	return int(time.Now().UnixNano()) % max
}