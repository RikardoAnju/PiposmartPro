package utils

import (
	"github.com/RikardoAnju/PiposmartPro/internal/config"
	"errors"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const registrationTicketTTL = 15 * time.Minute

type RegistrationTicketClaims struct {
	Purpose  string `json:"purpose"`
	Email    string `json:"email,omitempty"`
	GoogleID string `json:"google_id,omitempty"`
	AppleID  string `json:"apple_id,omitempty"`
	Phone    string `json:"phone,omitempty"`
	jwt.RegisteredClaims
}

func GenerateRegistrationTicket(purpose, email, googleID, phone string) (string, error) {
	return generateRegistrationTicket(purpose, email, googleID, "", phone)
}

func GenerateAppleRegistrationTicket(purpose, email, appleID, phone string) (string, error) {
	return generateRegistrationTicket(purpose, email, "", appleID, phone)
}

func generateRegistrationTicket(purpose, email, googleID, appleID, phone string) (string, error) {
	now := time.Now()
	claims := RegistrationTicketClaims{
		Purpose:  strings.TrimSpace(purpose),
		Email:    strings.ToLower(strings.TrimSpace(email)),
		GoogleID: strings.TrimSpace(googleID),
		AppleID:  strings.TrimSpace(appleID),
		Phone:    strings.TrimSpace(phone),
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    "piposmart-pro-api",
			Subject:   "registration",
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(registrationTicketTTL)),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(config.JWTSecret)
}

func ValidateRegistrationTicket(tokenText, expectedPurpose string) (*RegistrationTicketClaims, error) {
	tokenText = strings.TrimSpace(tokenText)
	if tokenText == "" {
		return nil, errors.New("registration ticket is required")
	}

	token, err := jwt.ParseWithClaims(
		tokenText,
		&RegistrationTicketClaims{},
		func(token *jwt.Token) (interface{}, error) {
			return config.JWTSecret, nil
		},
		jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}),
		jwt.WithIssuer("piposmart-pro-api"),
		jwt.WithSubject("registration"),
		jwt.WithExpirationRequired(),
	)
	if err != nil || !token.Valid {
		return nil, errors.New("registration ticket is invalid or expired")
	}

	claims, ok := token.Claims.(*RegistrationTicketClaims)
	if !ok || claims.Purpose != expectedPurpose {
		return nil, errors.New("registration ticket purpose mismatch")
	}
	return claims, nil
}
