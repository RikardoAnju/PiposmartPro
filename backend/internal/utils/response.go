package utils

import (
	// "net/http"

	"github.com/gin-gonic/gin"
)

// Response adalah struktur standar untuk API AyoCuci
type Response struct {
	Status  bool        `json:"status"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

// JSONResponse mengirimkan response JSON yang seragam
func JSONResponse(c *gin.Context, statusCode int, message string, data interface{}) {
	status := false
	if statusCode >= 200 && statusCode < 300 {
		status = true
	}

	c.JSON(statusCode, Response{
		Status:  status,
		Message: message,
		Data:    data,
	})
}

// ErrorResponse mempermudah pengiriman error
func ErrorResponse(c *gin.Context, statusCode int, message string) {
	// Pastikan field Status, Message, dan Data bisa diakses (Kapital)
	c.JSON(statusCode, Response{
		Status:  false,
		Message: message,
		Data:    nil,
	})
}