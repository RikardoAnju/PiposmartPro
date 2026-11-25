package utils

import (
	"strconv"
	"time"

	"github.com/RikardoAnju/PiposmartPro/internal/config"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"

	"github.com/RikardoAnju/PiposmartPro/internal/model"

	"github.com/golang-jwt/jwt/v5"
)

func GenerateToken(claims middleware.Claims) (string, error) {
	claims.ExpiresAt = jwt.NewNumericDate(time.Now().Add(config.JWTExpire))
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(config.JWTSecret)
}

// Taruh di internal/utils/converter.go atau generator.go
func ToUint(val interface{}) uint {
	switch v := val.(type) {
	case uint:
		return v
	case int:
		return uint(v)
	case string:
		i, _ := strconv.Atoi(v)
		return uint(i)
	case float64:
		return uint(v)
	default:
		return 0
	}
}

func ExtractUserID(user interface{}) string {
    switch v := user.(type) {
    case model.User:
        return strconv.Itoa(int(v.ID))
    case *model.User:
        return strconv.Itoa(int(v.ID))
    case model.Pegawai:
        return v.ID
    case *model.Pegawai:
        return v.ID
    default:
        return ""
    }
}


