package apple

import (
	"github.com/RikardoAnju/PiposmartPro/internal/config"
	"bytes"
	"crypto/ecdsa"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const (
	productionURL = "https://buy.itunes.apple.com/verifyReceipt"
	sandboxURL    = "https://sandbox.itunes.apple.com/verifyReceipt"
)

type VerifyClient struct {
	httpClient *http.Client
	password   string
}

type VerifyResponse struct {
	Status      int             `json:"status"`
	Environment string          `json:"environment"`
	Receipt     ReceiptEnvelope `json:"receipt"`
	LatestInfo  []InAppReceipt  `json:"latest_receipt_info"`
}

type ReceiptEnvelope struct {
	BundleID string         `json:"bundle_id"`
	InApp    []InAppReceipt `json:"in_app"`
}

type InAppReceipt struct {
	ProductID             string `json:"product_id"`
	TransactionID         string `json:"transaction_id"`
	OriginalTransactionID string `json:"original_transaction_id"`
}

func NewVerifyClient() *VerifyClient {
	return &VerifyClient{
		httpClient: &http.Client{Timeout: 20 * time.Second},
		password:   config.GetEnv("APPLE_SHARED_SECRET", ""),
	}
}

func (c *VerifyClient) VerifyReceipt(receiptData string, forceSandbox bool) (VerifyResponse, error) {
	if strings.HasPrefix(receiptData, "eyJ") {
		claims, err := c.VerifyJWSTransaction(receiptData)
		if err != nil {
			return VerifyResponse{}, fmt.Errorf("local JWS verification failed: %w", err)
		}
		env := "Production"
		if strings.EqualFold(claims.Environment, "sandbox") {
			env = "Sandbox"
		}
		return VerifyResponse{
			Status:      0,
			Environment: env,
			Receipt: ReceiptEnvelope{
				BundleID: claims.BundleID,
				InApp: []InAppReceipt{
					{
						ProductID:             claims.ProductID,
						TransactionID:         claims.TransactionID,
						OriginalTransactionID: claims.OriginalTransactionID,
					},
				},
			},
			LatestInfo: []InAppReceipt{
				{
					ProductID:             claims.ProductID,
					TransactionID:         claims.TransactionID,
					OriginalTransactionID: claims.OriginalTransactionID,
				},
			},
		}, nil
	}

	resp, err := c.verifyAgainstEndpoint(receiptData, forceSandbox)
	if err != nil {
		return resp, err
	}
	if resp.Status == 21007 && !forceSandbox {
		return c.verifyAgainstEndpoint(receiptData, true)
	}
	if resp.Status != 0 {
		return resp, fmt.Errorf("apple receipt verification failed with status %d", resp.Status)
	}
	return resp, nil
}

func (c *VerifyClient) verifyAgainstEndpoint(receiptData string, sandbox bool) (VerifyResponse, error) {
	endpoint := productionURL
	if sandbox {
		endpoint = sandboxURL
	}

	payload := map[string]interface{}{
		"receipt-data":             receiptData,
		"exclude-old-transactions": false,
	}
	if c.password != "" {
		payload["password"] = c.password
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return VerifyResponse{}, err
	}

	req, err := http.NewRequest(http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return VerifyResponse{}, err
	}
	req.Header.Set("Content-Type", "application/json")

	res, err := c.httpClient.Do(req)
	if err != nil {
		return VerifyResponse{}, err
	}
	defer res.Body.Close()

	raw, err := io.ReadAll(res.Body)
	if err != nil {
		return VerifyResponse{}, err
	}

	var parsed VerifyResponse
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return VerifyResponse{}, fmt.Errorf("failed to parse apple response: %w", err)
	}
	return parsed, nil
}

type AppleJWSTransactionClaims struct {
	TransactionID         string `json:"transactionId"`
	OriginalTransactionID string `json:"originalTransactionId"`
	ProductID             string `json:"productId"`
	BundleID              string `json:"bundleId"`
	Environment           string `json:"environment"`
	jwt.RegisteredClaims
}

func (c *VerifyClient) VerifyJWSTransaction(tokenStr string) (AppleJWSTransactionClaims, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &AppleJWSTransactionClaims{}, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodECDSA); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}

		x5c, ok := t.Header["x5c"].([]interface{})
		if !ok || len(x5c) == 0 {
			return nil, errors.New("missing x5c cert chain in header")
		}

		certDerStr, ok := x5c[0].(string)
		if !ok {
			return nil, errors.New("invalid x5c cert format")
		}

		certDer, err := base64.StdEncoding.DecodeString(certDerStr)
		if err != nil {
			return nil, fmt.Errorf("failed to decode leaf cert: %w", err)
		}

		cert, err := x509.ParseCertificate(certDer)
		if err != nil {
			return nil, fmt.Errorf("failed to parse leaf cert: %w", err)
		}

		if !containsApple(cert.Subject.Organization) && !containsApple([]string{cert.Issuer.CommonName}) {
			return nil, errors.New("certificate is not issued by Apple")
		}

		pubKey, ok := cert.PublicKey.(*ecdsa.PublicKey)
		if !ok {
			return nil, errors.New("public key is not ecdsa public key")
		}

		return pubKey, nil
	})

	if err != nil {
		return AppleJWSTransactionClaims{}, err
	}

	claims, ok := token.Claims.(*AppleJWSTransactionClaims)
	if !ok || !token.Valid {
		return AppleJWSTransactionClaims{}, errors.New("invalid token claims")
	}

	return *claims, nil
}

func containsApple(arr []string) bool {
	for _, s := range arr {
		if strings.Contains(strings.ToLower(s), "apple") {
			return true
		}
	}
	return false
}
