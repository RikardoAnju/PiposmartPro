package middleware

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

// AuthPermission mengunci endpoint berdasarkan modul dan aksi
func AuthPermission(module string, action string) gin.HandlerFunc {
	return func(c *gin.Context) {
		authPermission(c, module, []string{action})
	}
}

// AuthAnyPermission mengizinkan beberapa action alternatif dalam modul yang sama.
func AuthAnyPermission(module string, actions ...string) gin.HandlerFunc {
	return func(c *gin.Context) {
		authPermission(c, module, actions)
	}
}

func authPermission(c *gin.Context, module string, actions []string) {
	actorType, _ := c.Get("actor_type")
	if actorType == "user" {
		c.Next()
		return
	}

	permData, exists := c.Get("role_permissions")
	if !exists || permData == nil {
		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
			"status":  false,
			"message": "Akses ditolak: Anda tidak memiliki hak akses yang terdaftar",
		})
		return
	}

	var permString string
	switch v := permData.(type) {
	case string:
		permString = v
	case []byte:
		permString = string(v)
	default:
		permString = ""
	}

	for _, action := range actions {
		if HasPermission(permString, module, action) {
			c.Next()
			return
		}
	}

	actionLabel := ""
	if len(actions) > 0 {
		actionLabel = actions[0]
	}

	c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
		"status":  false,
		"message": "Anda tidak memiliki izin untuk " + actionLabel + " di modul " + module,
	})
}

// HasPermission melakukan verifikasi apakah modul/aksi ada dalam JSON permission
func HasPermission(jsonStr string, module string, action string) bool {
	// Bypass jika string all-access (Super Admin format)
	if jsonStr == `{"all":["*"]}` || jsonStr == `{"all": ["*"]}` {
		return true
	}

	// Compat layer: beberapa module lama/baru pernah bergeser penamaannya.
	// Alias dibuat agar role lama tidak langsung kehilangan akses saat deploy.
	module = normalizePermissionModule(module)

	// Parsing JSON ke Map untuk pengecekan dinamis
	var permissions map[string][]string
	if err := json.Unmarshal([]byte(jsonStr), &permissions); err != nil {
		return false
	}

	// Cek Hak Akses Modul Spesifik
	actions, ok := permissions[module]
	if !ok {
		// Cek Wildcard Global (jika ada role yang punya akses "all": ["*"])
		if globalActions, ok := permissions["all"]; ok {
			for _, a := range globalActions {
				if a == "*" {
					return true
				}
			}
		}
		return false
	}

	// Cek Hak Akses Aksi (Create/Read/Update/Delete atau Wildcard '*')
	for _, a := range actions {
		if a == action || a == "*" || a == "all" {
			return true
		}
	}

	return false
}

func normalizePermissionModule(module string) string {
	module = strings.TrimSpace(strings.ToLower(module))
	switch module {
	case "lead_ops":
		return "lead-ops"
	default:
		return module
	}
}
