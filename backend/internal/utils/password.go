package utils

import (
	"crypto/rand"
	"encoding/hex"
	"math/big"

	"golang.org/x/crypto/bcrypt"
)

// HashPassword meng-hash password menggunakan bcrypt
func HashPassword(password string) (string, error) {
	hashedBytes, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "", err
	}
	return string(hashedBytes), nil
	}

// CheckPasswordHash memeriksa kecocokan antara password dan hash-nya
func CheckPasswordHash(password, hashedPassword string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(password))
	return err == nil
}

func GenerateRandomString(n int) string {
	bytes := make([]byte, n)
	if _, err := rand.Read(bytes); err != nil {
		return "DefaultPassword123!" // Fallback
	}
	return hex.EncodeToString(bytes)
}

func GenerateReferralCode(n int) string {
	const charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Menghilangkan I, O, 0, 1 untuk menghindari kebingungan pembacaan
	result := make([]byte, n)
	for i := range result {
		num, err := rand.Int(rand.Reader, big.NewInt(int64(len(charset))))
		if err != nil {
			// Fallback jika crypto/rand gagal
			return "REF999" 
		}
		result[i] = charset[num.Int64()]
	}
	return string(result)
}