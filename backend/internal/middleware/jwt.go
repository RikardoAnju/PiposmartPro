// internal/middleware/jwt.go
package middleware

import (
	"github.com/RikardoAnju/PiposmartPro/internal/config"
	"errors"
	"log"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

// OutletStatusChecker is a hook that can be set by the main package to check if an outlet is active
var OutletStatusChecker func(outletID string) (bool, error)

type PegawaiSessionState struct {
	TokenVersion int
	Status       int
	Deleted      bool
}

var PegawaiSessionStateChecker func(actorID string) (PegawaiSessionState, error)

type Claims struct {
	ActorID      string `json:"actor_id"`
	ActorType    string `json:"actor_type"`
	OutletID     string `json:"outlet_id"`
	RoleID       string `json:"role_id"`
	Permissions  string `json:"permissions"` // JSON String dari ac_role
	PackageID    uint   `json:"package_id"`
	TokenVersion int    `json:"token_version,omitempty"`
	jwt.RegisteredClaims
}

func JWTAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		auth := c.GetHeader("Authorization")
		if auth == "" {
			log.Printf(
				"auth:jwt unauthorized reason=missing_authorization method=%s path=%s ip=%s ua=%q",
				c.Request.Method,
				c.Request.URL.Path,
				c.ClientIP(),
				c.Request.UserAgent(),
			)
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"message": "Missing token"})
			return
		}

		if !strings.HasPrefix(auth, "Bearer ") {
			log.Printf(
				"auth:jwt unauthorized reason=invalid_bearer_format method=%s path=%s ip=%s auth_prefix=%q",
				c.Request.Method,
				c.Request.URL.Path,
				c.ClientIP(),
				safePrefix(auth),
			)
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"message": "Invalid token"})
			return
		}

		tokenStr := strings.TrimSpace(strings.TrimPrefix(auth, "Bearer "))
		if tokenStr == "" {
			log.Printf(
				"auth:jwt unauthorized reason=empty_token method=%s path=%s ip=%s",
				c.Request.Method,
				c.Request.URL.Path,
				c.ClientIP(),
			)
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"message": "Missing token"})
			return
		}

		token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(t *jwt.Token) (interface{}, error) {
			return config.JWTSecret, nil
		})

		if err != nil || !token.Valid {
			log.Printf(
				"auth:jwt unauthorized reason=%s method=%s path=%s ip=%s token_prefix=%s",
				describeJWTError(err, token),
				c.Request.Method,
				c.Request.URL.Path,
				c.ClientIP(),
				safePrefix(tokenStr),
			)
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"message": "Invalid token"})
			return
		}

		claims, ok := token.Claims.(*Claims)
		if !ok {
			log.Printf(
				"auth:jwt unauthorized reason=claims_type_assert_failed method=%s path=%s ip=%s token_prefix=%s",
				c.Request.Method,
				c.Request.URL.Path,
				c.ClientIP(),
				safePrefix(tokenStr),
			)
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"message": "Failed to parse claims"})
			return
		}

		// Set ke context agar bisa dibaca oleh middleware dan controller
		// Kita simpan semuanya sebagai string/tipe aslinya agar tidak ada data loss
		c.Set("actor_id", claims.ActorID)
		c.Set("actor_type", claims.ActorType)
		c.Set("outlet_id", claims.OutletID)
		c.Set("role_id", claims.RoleID)
		c.Set("role_permissions", claims.Permissions)
		c.Set("package_id", claims.PackageID)
		c.Set("token_version", claims.TokenVersion)

		// ---------------------------------------------------------------------
		// Cek Status Outlet
		// ---------------------------------------------------------------------
		if claims.OutletID != "" && OutletStatusChecker != nil {
			isActive, err := OutletStatusChecker(claims.OutletID)
			if err == nil && !isActive {
				log.Printf(
					"auth:jwt unauthorized reason=outlet_inactive method=%s path=%s ip=%s outlet=%s",
					c.Request.Method,
					c.Request.URL.Path,
					c.ClientIP(),
					claims.OutletID,
				)
				c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
					"status":       false,
					"message":      "Akses Ditolak: Outlet ini telah dinonaktifkan. Anda telah di-logout dari sesi ini.",
					"force_logout": true,
				})
				return
			}
		}

		if claims.ActorType == "pegawai" && PegawaiSessionStateChecker != nil {
			state, err := PegawaiSessionStateChecker(claims.ActorID)
			if err != nil || state.Status != 1 || state.Deleted {
				log.Printf(
					"auth:jwt unauthorized reason=employee_inactive_or_deleted method=%s path=%s ip=%s actor=%s status=%d deleted=%t err=%v",
					c.Request.Method, c.Request.URL.Path, c.ClientIP(), claims.ActorID, state.Status, state.Deleted, err,
				)
				c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
					"status":       false,
					"message":      "Akun pegawai telah dinonaktifkan. Hubungi pemilik outlet.",
					"force_logout": true,
				})
				return
			}
			if state.TokenVersion != claims.TokenVersion {
				log.Printf(
					"auth:jwt unauthorized reason=token_version_mismatch method=%s path=%s ip=%s actor=%s token_version=%d current_version=%d",
					c.Request.Method,
					c.Request.URL.Path,
					c.ClientIP(),
					claims.ActorID,
					claims.TokenVersion,
					state.TokenVersion,
				)
				c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
					"status":       false,
					"message":      "Sesi telah diakhiri. Silakan login ulang.",
					"force_logout": true,
				})
				return
			}
		}

		c.Next()
	}
}

func safePrefix(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return "-"
	}
	if len(value) > 16 {
		return value[:16]
	}
	return value
}

func describeJWTError(err error, token *jwt.Token) string {
	switch {
	case errors.Is(err, jwt.ErrTokenMalformed):
		return "token_malformed"
	case errors.Is(err, jwt.ErrTokenSignatureInvalid):
		return "token_signature_invalid"
	case errors.Is(err, jwt.ErrTokenExpired):
		return "token_expired"
	case errors.Is(err, jwt.ErrTokenNotValidYet):
		return "token_not_valid_yet"
	case errors.Is(err, jwt.ErrTokenUnverifiable):
		return "token_unverifiable"
	case err != nil:
		return "token_parse_error:" + err.Error()
	case token == nil:
		return "token_nil"
	case !token.Valid:
		return "token_invalid"
	default:
		return "unknown"
	}
}
