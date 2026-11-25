package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// AdminOnly protects routes by checking the actor_type stored in the context
// by the AuthMiddleware. This version does NOT import the utils package.
func AdminOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		// We get the value from the context, which was set by AuthMiddleware
		actorType, exists := c.Get("actor_type")

		if !exists || actorType != "admin" {
			// Using native gin.H instead of utils.ErrorResponse
			c.JSON(http.StatusForbidden, gin.H{
				"status":  false,
				"message": "Akses ditolak: Hanya untuk Super Admin",
			})
			c.Abort()
			return
		}

		c.Next()
	}
}

// MasterAdminOnly protects routes that can ONLY be accessed by the master admin (IsMaster=true)
func MasterAdminOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		actorType, _ := c.Get("actor_type")
		if actorType != "admin" {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"status":  false,
				"message": "Akses ditolak: Hanya untuk Master Admin",
			})
			return
		}

		// Cek permissions: master admin punya {"all": ["*"]}
		permData, _ := c.Get("role_permissions")
		permStr, _ := permData.(string)
		if !HasPermission(permStr, "all", "*") {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"status":  false,
				"message": "Akses ditolak: Fitur ini hanya untuk Master Admin",
			})
			return
		}

		c.Next()
	}
}

// AdminPermission middleware: cek permission admin per modul per aksi.
// Master admin (permissions {"all":["*"]}) akan bypass otomatis.
func AdminPermission(module, action string) gin.HandlerFunc {
	return func(c *gin.Context) {
		actorType, _ := c.Get("actor_type")
		if actorType != "admin" {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"status":  false,
				"message": "Akses ditolak: Bukan akun admin",
			})
			return
		}

		permData, exists := c.Get("role_permissions")
		if !exists || permData == nil {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"status":  false,
				"message": "Akses ditolak: Tidak ada hak akses terdaftar",
			})
			return
		}

		var permStr string
		switch v := permData.(type) {
		case string:
			permStr = v
		case []byte:
			permStr = string(v)
		default:
			permStr = ""
		}

		if !HasPermission(permStr, module, action) {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"status":  false,
				"message": "Anda tidak memiliki izin untuk " + action + " di modul " + module,
			})
			return
		}

		c.Next()
	}
}