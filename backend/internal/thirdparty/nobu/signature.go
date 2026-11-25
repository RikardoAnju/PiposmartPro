package nobu

import (
	"crypto"
	"crypto/hmac"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/sha512"
	"crypto/x509"
	"encoding/base64"
	"encoding/pem"
	"fmt"
	"strings"
)

func SignToken(privateKeyPEM, clientID, timestamp string) (string, error) {
	block, _ := pem.Decode([]byte(privateKeyPEM))
	if block == nil {
		return "", fmt.Errorf("invalid Nobu private key PEM")
	}
	var key *rsa.PrivateKey
	if parsed, err := x509.ParsePKCS1PrivateKey(block.Bytes); err == nil {
		key = parsed
	} else {
		parsedPKCS8, err := x509.ParsePKCS8PrivateKey(block.Bytes)
		if err != nil {
			return "", fmt.Errorf("parse Nobu private key: %w", err)
		}
		var ok bool
		key, ok = parsedPKCS8.(*rsa.PrivateKey)
		if !ok {
			return "", fmt.Errorf("Nobu private key is not RSA")
		}
	}
	// Nobu confirmed the UAT token stringToSign excludes the Applytoken prefix.
	digest := sha256.Sum256([]byte(clientID + "|" + timestamp))
	sig, err := rsa.SignPKCS1v15(rand.Reader, key, crypto.SHA256, digest[:])
	if err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(sig), nil
}

// VerifyRSASignature memverifikasi X-SIGNATURE asymmetric (RSA PKCS1v15 SHA256,
// base64) yang dikirim Nobu, misalnya pada request token B2B ke endpoint kita.
// stringToSign untuk token B2B = X-CLIENT-KEY + "|" + X-TIMESTAMP.
func VerifyRSASignature(publicKeyPEM, stringToSign, signatureB64 string) error {
	block, _ := pem.Decode([]byte(publicKeyPEM))
	if block == nil {
		return fmt.Errorf("invalid Nobu public key PEM")
	}
	pub, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return fmt.Errorf("parse Nobu public key: %w", err)
	}
	rsaPub, ok := pub.(*rsa.PublicKey)
	if !ok {
		return fmt.Errorf("Nobu public key is not RSA")
	}
	sig, err := base64.StdEncoding.DecodeString(signatureB64)
	if err != nil {
		return fmt.Errorf("invalid Nobu signature encoding: %w", err)
	}
	digest := sha256.Sum256([]byte(stringToSign))
	return rsa.VerifyPKCS1v15(rsaPub, crypto.SHA256, digest[:], sig)
}

func SignTransaction(clientSecret, method, path, accessToken, timestamp, body string) string {
	h := sha256.Sum256([]byte(body))
	stringToSign := strings.ToUpper(method) + ":" + path + ":" + accessToken + ":" + fmt.Sprintf("%x", h[:]) + ":" + timestamp
	m := hmac.New(sha512.New, []byte(clientSecret))
	_, _ = m.Write([]byte(stringToSign))
	return base64.StdEncoding.EncodeToString(m.Sum(nil))
}
