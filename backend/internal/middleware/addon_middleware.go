package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// FeatureChecker adalah interface lokal agar middleware tidak perlu import package service (Mencegah Import Cycle)
type FeatureChecker interface {
	CheckFeatureAccess(outletID string, featureLink string) (bool, error)
}

// RequireAddon mengunci fitur berdasarkan Add-on eceran yang dibeli
func RequireAddon(featureLink string, svc FeatureChecker) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Ambil outlet_id dari context (setelah JWTAuth)
		outletID, exists := c.Get("outlet_id")
		if !exists || outletID == "" {
			c.JSON(http.StatusUnauthorized, gin.H{
				"status":  false,
				"message": "Sesi tidak valid atau outlet tidak ditemukan",
			})
			c.Abort()
			return
		}

		// Jalankan pengecekan akses fitur
		hasAccess, err := svc.CheckFeatureAccess(outletID.(string), featureLink)
		
		// Jika tidak punya akses atau ada error database
		if err != nil || !hasAccess {
			c.JSON(http.StatusPaymentRequired, gin.H{
				"status":  false,
				"code":    "ADDON_REQUIRED",
				"feature": featureLink,
				"message": "Fitur ini memerlukan Add-on aktif. Silakan lakukan aktivasi terlebih dahulu.",
			})
			c.Abort()
			return
		}

		c.Next()
	}
}