package push

import (
	"github.com/RikardoAnju/PiposmartPro/internal/config"
	"bytes"
	"context"
	"crypto/rsa"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const fcmScope = "https://www.googleapis.com/auth/firebase.messaging"

type serviceAccountConfig struct {
	ProjectID   string `json:"project_id"`
	ClientEmail string `json:"client_email"`
	PrivateKey  string `json:"private_key"`
	TokenURI    string `json:"token_uri"`
}

type tokenCache struct {
	AccessToken string
	ExpiresAt   time.Time
}

var (
	fcmMu        sync.Mutex
	fcmLoaded    bool
	fcmDisabled  bool
	fcmConfig    serviceAccountConfig
	fcmTokenData tokenCache
	httpClient   = &http.Client{Timeout: 15 * time.Second}
)

func SendNotificationToTokens(ctx context.Context, tokens []string, title, body string, data map[string]string) {
	if len(tokens) == 0 {
		return
	}

	cfg, err := loadServiceAccount()
	if err != nil {
		log.Printf("push:fcm config unavailable: %v", err)
		return
	}

	accessToken, err := accessToken(ctx, cfg)
	if err != nil {
		log.Printf("push:fcm access token error: %v", err)
		return
	}

	for _, token := range tokens {
		if strings.TrimSpace(token) == "" {
			continue
		}
		if err := sendSingle(ctx, cfg, accessToken, token, title, body, data); err != nil {
			log.Printf("push:fcm send failed for token %s: %v", redactToken(token), err)
		}
	}
}

func loadServiceAccount() (serviceAccountConfig, error) {
	fcmMu.Lock()
	defer fcmMu.Unlock()

	if fcmLoaded {
		if fcmDisabled {
			return serviceAccountConfig{}, fmt.Errorf("not configured")
		}
		return fcmConfig, nil
	}

	raw := strings.TrimSpace(config.GetEnv("FIREBASE_SERVICE_ACCOUNT_JSON", ""))
	if raw == "" {
		rawB64 := strings.TrimSpace(config.GetEnv("FIREBASE_SERVICE_ACCOUNT_JSON_BASE64", ""))
		if rawB64 != "" {
			decoded, err := base64.StdEncoding.DecodeString(rawB64)
			if err != nil {
				fcmLoaded = true
				fcmDisabled = true
				return serviceAccountConfig{}, fmt.Errorf("decode base64 service account: %w", err)
			}
			raw = string(decoded)
		}
	}

	if raw == "" {
		fcmLoaded = true
		fcmDisabled = true
		return serviceAccountConfig{}, fmt.Errorf("FIREBASE_SERVICE_ACCOUNT_JSON not set")
	}

	var cfg serviceAccountConfig
	if err := json.Unmarshal([]byte(raw), &cfg); err != nil {
		fcmLoaded = true
		fcmDisabled = true
		return serviceAccountConfig{}, fmt.Errorf("parse service account json: %w", err)
	}

	if cfg.TokenURI == "" {
		cfg.TokenURI = "https://oauth2.googleapis.com/token"
	}
	if cfg.ProjectID == "" || cfg.ClientEmail == "" || cfg.PrivateKey == "" {
		fcmLoaded = true
		fcmDisabled = true
		return serviceAccountConfig{}, fmt.Errorf("incomplete firebase service account")
	}

	fcmConfig = cfg
	fcmLoaded = true
	return fcmConfig, nil
}

func accessToken(ctx context.Context, cfg serviceAccountConfig) (string, error) {
	fcmMu.Lock()
	if fcmTokenData.AccessToken != "" && time.Now().Before(fcmTokenData.ExpiresAt.Add(-1*time.Minute)) {
		token := fcmTokenData.AccessToken
		fcmMu.Unlock()
		return token, nil
	}
	fcmMu.Unlock()

	assertion, err := signedJWT(cfg)
	if err != nil {
		return "", err
	}

	form := url.Values{}
	form.Set("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer")
	form.Set("assertion", assertion)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, cfg.TokenURI, strings.NewReader(form.Encode()))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return "", fmt.Errorf("token endpoint %d: %s", resp.StatusCode, string(bodyBytes))
	}

	var payload struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int64  `json:"expires_in"`
	}
	if err := json.Unmarshal(bodyBytes, &payload); err != nil {
		return "", err
	}

	if payload.AccessToken == "" {
		return "", fmt.Errorf("empty oauth access token")
	}

	fcmMu.Lock()
	fcmTokenData = tokenCache{
		AccessToken: payload.AccessToken,
		ExpiresAt:   time.Now().Add(time.Duration(payload.ExpiresIn) * time.Second),
	}
	fcmMu.Unlock()

	return payload.AccessToken, nil
}

func signedJWT(cfg serviceAccountConfig) (string, error) {
	privateKey, err := parsePrivateKey(cfg.PrivateKey)
	if err != nil {
		return "", err
	}

	now := time.Now()
	claims := jwt.MapClaims{
		"iss":   cfg.ClientEmail,
		"sub":   cfg.ClientEmail,
		"aud":   cfg.TokenURI,
		"scope": fcmScope,
		"iat":   now.Unix(),
		"exp":   now.Add(time.Hour).Unix(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	return token.SignedString(privateKey)
}

func parsePrivateKey(key string) (*rsa.PrivateKey, error) {
	block, _ := pem.Decode([]byte(key))
	if block == nil {
		return nil, fmt.Errorf("invalid pem private key")
	}

	if parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes); err == nil {
		if rsaKey, ok := parsed.(*rsa.PrivateKey); ok {
			return rsaKey, nil
		}
	}

	if parsed, err := x509.ParsePKCS1PrivateKey(block.Bytes); err == nil {
		return parsed, nil
	}

	return nil, fmt.Errorf("unsupported private key format")
}

func sendSingle(ctx context.Context, cfg serviceAccountConfig, accessToken, token, title, body string, data map[string]string) error {
	const channelID = "piposmart_pro_alerts_v2"
	const notificationSound = "notif"

	notificationPayload := map[string]string{
		"title": title,
		"body":  body,
	}
	androidNotificationPayload := map[string]string{
		"channel_id": channelID,
		"icon":       "ic_notification",
		"color":      "#FF5A36",
		"sound":      notificationSound,
	}
	if imageURL := strings.TrimSpace(data["image_url"]); imageURL != "" {
		notificationPayload["image"] = imageURL
		androidNotificationPayload["image"] = imageURL
	}

	apnsApsPayload := map[string]interface{}{
		"alert": map[string]string{
			"title": title,
			"body":  body,
		},
		"sound": "notif.wav",
	}

	apnsPayload := map[string]interface{}{
		"aps": apnsApsPayload,
	}

	apnsFcmOptions := map[string]string{}
	if imageURL := strings.TrimSpace(data["image_url"]); imageURL != "" {
		apnsApsPayload["mutable-content"] = 1
		apnsFcmOptions["image"] = imageURL
	}

	payload := map[string]interface{}{
		"message": map[string]interface{}{
			"token":        token,
			"notification": notificationPayload,
			"data":         data,
			"android": map[string]interface{}{
				"priority":     "high",
				"notification": androidNotificationPayload,
			},
			"apns": map[string]interface{}{
				"headers": map[string]string{
					"apns-push-type": "alert",
					"apns-priority":  "10",
				},
				"payload":     apnsPayload,
				"fcm_options": apnsFcmOptions,
			},
		},
	}

	bodyBytes, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	endpoint := fmt.Sprintf("https://fcm.googleapis.com/v1/projects/%s/messages:send", cfg.ProjectID)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(bodyBytes))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return fmt.Errorf("fcm status %d: %s", resp.StatusCode, string(respBody))
	}
	return nil
}

func redactToken(token string) string {
	if len(token) <= 10 {
		return token
	}
	return token[:6] + "..." + token[len(token)-4:]
}
