package fonnte

import (
	"github.com/RikardoAnju/PiposmartPro/internal/config"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"net/textproto"
	"strings"
	"sync/atomic"
)

type SendResult struct {
	Target      string `json:"target"`
	HTTPStatus  int    `json:"http_status"`
	Success     bool   `json:"success"`
	Reason      string `json:"reason"`
	RawResponse string `json:"raw_response"`
	Provider    string `json:"provider"`
}

type ValidateResult struct {
	Target        string `json:"target"`
	HTTPStatus    int    `json:"http_status"`
	Success       bool   `json:"success"`
	Reason        string `json:"reason"`
	RawResponse   string `json:"raw_response"`
	Provider      string `json:"provider"`
	IsRegistered  bool   `json:"is_registered"`
	RegisteredRaw []any  `json:"registered_raw,omitempty"`
}

type apiResponse struct {
	Status interface{} `json:"status"`
	Reason string      `json:"reason"`
	Detail string      `json:"detail"`
}

type validateAPIResponse struct {
	Status        interface{} `json:"status"`
	Reason        string      `json:"reason"`
	Detail        string      `json:"detail"`
	Registered    []any       `json:"registered"`
	NotRegistered []any       `json:"not_registered"`
}

type credential struct {
	Token string
	Label string
}

var sendCounter uint64

func normalizePhone(target string) string {
	digits := strings.Map(func(r rune) rune {
		if r >= '0' && r <= '9' {
			return r
		}
		return -1
	}, target)

	switch {
	case strings.HasPrefix(digits, "62"):
		return digits
	case strings.HasPrefix(digits, "0"):
		return "62" + digits[1:]
	case strings.HasPrefix(digits, "8"):
		return "62" + digits
	default:
		return digits
	}
}

func parseSuccessFlag(value interface{}) bool {
	switch v := value.(type) {
	case bool:
		return v
	case float64:
		return v != 0
	case string:
		normalized := strings.TrimSpace(strings.ToLower(v))
		return normalized == "true" || normalized == "1" || normalized == "success" || normalized == "sent"
	default:
		return false
	}
}

func (r *SendResult) Summary() string {
	parts := []string{
		fmt.Sprintf("target=%s", r.Target),
		fmt.Sprintf("provider=%s", r.Provider),
		fmt.Sprintf("http=%d", r.HTTPStatus),
	}
	if r.Reason != "" {
		parts = append(parts, fmt.Sprintf("reason=%s", r.Reason))
	}
	if r.RawResponse != "" {
		parts = append(parts, fmt.Sprintf("response=%s", r.RawResponse))
	}
	return strings.Join(parts, " | ")
}

func (r *ValidateResult) Summary() string {
	parts := []string{
		fmt.Sprintf("target=%s", r.Target),
		fmt.Sprintf("provider=%s", r.Provider),
		fmt.Sprintf("http=%d", r.HTTPStatus),
		fmt.Sprintf("registered=%t", r.IsRegistered),
	}
	if r.Reason != "" {
		parts = append(parts, fmt.Sprintf("reason=%s", r.Reason))
	}
	if r.RawResponse != "" {
		parts = append(parts, fmt.Sprintf("response=%s", r.RawResponse))
	}
	return strings.Join(parts, " | ")
}

func loadCredentials() []credential {
	rawTokens := []string{
		config.GetEnv("FONNTE_TOKEN_1", ""),
		config.GetEnv("FONNTE_TOKEN_2", ""),
	}
	if combined := strings.TrimSpace(config.GetEnv("FONNTE_TOKENS", "")); combined != "" {
		rawTokens = append(rawTokens, strings.Split(combined, ",")...)
	}

	if single := strings.TrimSpace(config.GetEnv("FONNTE_TOKEN", "")); single != "" {
		rawTokens = append(rawTokens, single)
	}

	seen := make(map[string]struct{})
	creds := make([]credential, 0, len(rawTokens))
	for idx, token := range rawTokens {
		trimmed := strings.TrimSpace(token)
		if trimmed == "" {
			continue
		}
		if _, exists := seen[trimmed]; exists {
			continue
		}
		seen[trimmed] = struct{}{}
		creds = append(creds, credential{
			Token: trimmed,
			Label: fmt.Sprintf("fonnte-%d", idx+1),
		})
	}

	return creds
}

func sendWithCredential(target string, message string, cred credential) (*SendResult, error) {
	url := "https://api.fonnte.com/send"
	normalizedTarget := normalizePhone(target)
	if normalizedTarget == "" {
		return nil, errors.New("target phone is empty after normalization")
	}

	payload := map[string]string{
		"target":  normalizedTarget,
		"message": message,
	}
	jsonPayload, _ := json.Marshal(payload)

	req, _ := http.NewRequest("POST", url, bytes.NewBuffer(jsonPayload))
	req.Header.Set("Authorization", cred.Token)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return &SendResult{
			Target:     normalizedTarget,
			HTTPStatus: 0,
			Success:    false,
			Reason:     err.Error(),
		}, err
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	rawBody := strings.TrimSpace(string(body))

	result := &SendResult{
		Target:      normalizedTarget,
		HTTPStatus:  resp.StatusCode,
		Success:     resp.StatusCode >= 200 && resp.StatusCode < 300,
		RawResponse: rawBody,
		Provider:    cred.Label,
	}

	var parsed apiResponse
	if len(body) > 0 && json.Unmarshal(body, &parsed) == nil {
		if parsed.Reason != "" {
			result.Reason = parsed.Reason
		} else if parsed.Detail != "" {
			result.Reason = parsed.Detail
		}
		if parsed.Status != nil {
			result.Success = result.Success && parseSuccessFlag(parsed.Status)
		}
	}

	if !result.Success {
		if result.Reason == "" {
			result.Reason = http.StatusText(resp.StatusCode)
		}
		return result, fmt.Errorf("fonnte send rejected: %s", result.Summary())
	}

	if result.Reason == "" {
		result.Reason = "accepted"
	}

	return result, nil
}

func buildMultipartBody(fields map[string]string) (*bytes.Buffer, string, error) {
	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)

	for key, value := range fields {
		header := textproto.MIMEHeader{}
		header.Set("Content-Disposition", fmt.Sprintf(`form-data; name="%s"`, key))
		header.Set("Content-Type", "text/plain; charset=utf-8")

		part, err := writer.CreatePart(header)
		if err != nil {
			return nil, "", err
		}
		if _, err := io.WriteString(part, value); err != nil {
			return nil, "", err
		}
	}

	if err := writer.Close(); err != nil {
		return nil, "", err
	}

	return body, writer.FormDataContentType(), nil
}

func validateWithCredential(target string, cred credential) (*ValidateResult, error) {
	url := "https://api.fonnte.com/validate"
	normalizedTarget := normalizePhone(target)
	if normalizedTarget == "" {
		return nil, errors.New("target phone is empty after normalization")
	}

	body, contentType, err := buildMultipartBody(map[string]string{
		"target":      normalizedTarget,
		"countryCode": "62",
	})
	if err != nil {
		return nil, err
	}

	req, _ := http.NewRequest("POST", url, body)
	req.Header.Set("Authorization", cred.Token)
	req.Header.Set("Content-Type", contentType)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return &ValidateResult{
			Target:     normalizedTarget,
			HTTPStatus: 0,
			Success:    false,
			Reason:     err.Error(),
		}, err
	}
	defer resp.Body.Close()

	rawBodyBytes, _ := io.ReadAll(resp.Body)
	rawBody := strings.TrimSpace(string(rawBodyBytes))

	result := &ValidateResult{
		Target:      normalizedTarget,
		HTTPStatus:  resp.StatusCode,
		Success:     resp.StatusCode >= 200 && resp.StatusCode < 300,
		RawResponse: rawBody,
		Provider:    cred.Label,
	}

	var parsed validateAPIResponse
	if len(rawBodyBytes) > 0 && json.Unmarshal(rawBodyBytes, &parsed) == nil {
		if parsed.Reason != "" {
			result.Reason = parsed.Reason
		} else if parsed.Detail != "" {
			result.Reason = parsed.Detail
		}
		if parsed.Status != nil {
			result.Success = result.Success && parseSuccessFlag(parsed.Status)
		}
		result.RegisteredRaw = parsed.Registered

		lowerHint := strings.ToLower(strings.TrimSpace(
			strings.Join([]string{parsed.Reason, parsed.Detail, rawBody}, " "),
		))
		switch {
		case len(parsed.Registered) > 0 && len(parsed.NotRegistered) == 0:
			result.IsRegistered = true
		case len(parsed.NotRegistered) > 0:
			result.IsRegistered = false
		case strings.Contains(lowerHint, "not registered") ||
			strings.Contains(lowerHint, "not terdaftar") ||
			strings.Contains(lowerHint, "belum terdaftar"):
			result.IsRegistered = false
		case strings.Contains(lowerHint, "registered") ||
			strings.Contains(lowerHint, "terdaftar") ||
			strings.Contains(lowerHint, "active") ||
			strings.Contains(lowerHint, "aktif"):
			result.IsRegistered = true
		default:
			result.IsRegistered = result.Success
		}
	}

	if !result.Success {
		if result.Reason == "" {
			result.Reason = http.StatusText(resp.StatusCode)
		}
		return result, fmt.Errorf("fonnte validate rejected: %s", result.Summary())
	}

	if !result.IsRegistered {
		if result.Reason == "" {
			result.Reason = "nomor belum terdaftar di WhatsApp"
		}
		return result, fmt.Errorf("whatsapp number is not registered: %s", result.Summary())
	}

	if result.Reason == "" {
		result.Reason = "registered"
	}

	return result, nil
}

// sendGroupWithCredential mengirim pesan ke target APA ADANYA (tanpa
// normalizePhone), dipakai untuk target grup WhatsApp berformat "xxx@g.us".
func sendGroupWithCredential(target string, message string, cred credential) (*SendResult, error) {
	url := "https://api.fonnte.com/send"
	if strings.TrimSpace(target) == "" {
		return nil, errors.New("group target is empty")
	}

	payload := map[string]string{
		"target":  target,
		"message": message,
	}
	jsonPayload, _ := json.Marshal(payload)

	req, _ := http.NewRequest("POST", url, bytes.NewBuffer(jsonPayload))
	req.Header.Set("Authorization", cred.Token)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return &SendResult{Target: target, Success: false, Reason: err.Error()}, err
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	rawBody := strings.TrimSpace(string(body))

	result := &SendResult{
		Target:      target,
		HTTPStatus:  resp.StatusCode,
		Success:     resp.StatusCode >= 200 && resp.StatusCode < 300,
		RawResponse: rawBody,
		Provider:    cred.Label,
	}

	var parsed apiResponse
	if len(body) > 0 && json.Unmarshal(body, &parsed) == nil {
		if parsed.Reason != "" {
			result.Reason = parsed.Reason
		} else if parsed.Detail != "" {
			result.Reason = parsed.Detail
		}
		if parsed.Status != nil {
			result.Success = result.Success && parseSuccessFlag(parsed.Status)
		}
	}

	if !result.Success {
		if result.Reason == "" {
			result.Reason = http.StatusText(resp.StatusCode)
		}
		return result, fmt.Errorf("fonnte group send rejected: %s", result.Summary())
	}
	if result.Reason == "" {
		result.Reason = "accepted"
	}
	return result, nil
}

// SendGroup mengirim pesan ke grup WhatsApp (target "xxx@g.us") memakai
// rotasi kredensial yang sama dengan SendWhatsApp, tanpa normalisasi nomor.
func SendGroup(groupID string, message string) (*SendResult, error) {
	creds := loadCredentials()
	if len(creds) == 0 {
		return nil, errors.New("one of FONNTE_TOKEN, FONNTE_TOKEN_1, FONNTE_TOKEN_2, or FONNTE_TOKENS is required")
	}

	start := int(atomic.AddUint64(&sendCounter, 1)-1) % len(creds)
	var lastResult *SendResult
	var lastErr error
	for offset := 0; offset < len(creds); offset++ {
		cred := creds[(start+offset)%len(creds)]
		result, err := sendGroupWithCredential(groupID, message, cred)
		if err == nil {
			return result, nil
		}
		lastResult = result
		lastErr = err
	}
	return lastResult, lastErr
}

func SendWhatsApp(target string, message string) (*SendResult, error) {
	creds := loadCredentials()
	if len(creds) == 0 {
		return nil, errors.New("one of FONNTE_TOKEN, FONNTE_TOKEN_1, FONNTE_TOKEN_2, or FONNTE_TOKENS is required")
	}

	start := int(atomic.AddUint64(&sendCounter, 1)-1) % len(creds)
	var lastResult *SendResult
	var lastErr error

	for offset := 0; offset < len(creds); offset++ {
		cred := creds[(start+offset)%len(creds)]
		result, err := sendWithCredential(target, message, cred)
		if err == nil {
			return result, nil
		}
		lastResult = result
		lastErr = err
	}

	return lastResult, lastErr
}

func ValidateWhatsApp(target string) (*ValidateResult, error) {
	creds := loadCredentials()
	if len(creds) == 0 {
		return nil, errors.New("one of FONNTE_TOKEN, FONNTE_TOKEN_1, FONNTE_TOKEN_2, or FONNTE_TOKENS is required")
	}

	start := int(atomic.AddUint64(&sendCounter, 1)-1) % len(creds)
	var lastResult *ValidateResult
	var lastErr error

	for offset := 0; offset < len(creds); offset++ {
		cred := creds[(start+offset)%len(creds)]
		result, err := validateWithCredential(target, cred)
		if err == nil {
			return result, nil
		}
		lastResult = result
		lastErr = err
	}

	return lastResult, lastErr
}
