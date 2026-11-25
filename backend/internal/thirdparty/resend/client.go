package resend

import (
	"github.com/RikardoAnju/PiposmartPro/internal/config"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

const defaultEndpoint = "https://api.resend.com/emails"

type SendEmailRequest struct {
	To      string
	Subject string
	HTML    string
	Text    string
}

type SendEmailResult struct {
	ID         string `json:"id"`
	To         string `json:"to"`
	HTTPStatus int    `json:"http_status"`
	Success    bool   `json:"success"`
	Reason     string `json:"reason"`
	Provider   string `json:"provider"`
}

type sendEmailPayload struct {
	From    string   `json:"from"`
	To      []string `json:"to"`
	Subject string   `json:"subject"`
	HTML    string   `json:"html,omitempty"`
	Text    string   `json:"text,omitempty"`
	ReplyTo []string `json:"reply_to,omitempty"`
}

type sendEmailResponse struct {
	ID      string `json:"id"`
	Message string `json:"message"`
	Name    string `json:"name"`
}

func (r *SendEmailResult) Summary() string {
	parts := []string{
		fmt.Sprintf("to=%s", r.To),
		fmt.Sprintf("provider=%s", r.Provider),
		fmt.Sprintf("http=%d", r.HTTPStatus),
	}
	if r.ID != "" {
		parts = append(parts, fmt.Sprintf("id=%s", r.ID))
	}
	if r.Reason != "" {
		parts = append(parts, fmt.Sprintf("reason=%s", r.Reason))
	}
	return strings.Join(parts, " | ")
}

func SendEmail(input SendEmailRequest) (*SendEmailResult, error) {
	apiKey := strings.TrimSpace(config.GetEnv("RESEND_API_KEY", ""))
	fromEmail := strings.TrimSpace(config.GetEnv("RESEND_FROM_EMAIL", ""))
	fromName := strings.TrimSpace(config.GetEnv("RESEND_FROM_NAME", "AyoCuci"))
	replyTo := strings.TrimSpace(config.GetEnv("RESEND_REPLY_TO", ""))
	endpoint := strings.TrimSpace(config.GetEnv("RESEND_API_BASE_URL", defaultEndpoint))

	if apiKey == "" {
		return nil, fmt.Errorf("RESEND_API_KEY belum dikonfigurasi")
	}
	if fromEmail == "" {
		return nil, fmt.Errorf("RESEND_FROM_EMAIL belum dikonfigurasi")
	}

	to := strings.TrimSpace(input.To)
	if to == "" {
		return nil, fmt.Errorf("email tujuan wajib diisi")
	}

	from := fromEmail
	if fromName != "" {
		from = fmt.Sprintf("%s <%s>", fromName, fromEmail)
	}

	payload := sendEmailPayload{
		From:    from,
		To:      []string{to},
		Subject: strings.TrimSpace(input.Subject),
		HTML:    strings.TrimSpace(input.HTML),
		Text:    strings.TrimSpace(input.Text),
	}
	if replyTo != "" {
		payload.ReplyTo = []string{replyTo}
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest(http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return &SendEmailResult{
			To:       to,
			Success:  false,
			Reason:   err.Error(),
			Provider: "resend",
		}, err
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	raw := strings.TrimSpace(string(respBody))
	result := &SendEmailResult{
		To:         to,
		HTTPStatus: resp.StatusCode,
		Success:    resp.StatusCode >= 200 && resp.StatusCode < 300,
		Provider:   "resend",
	}

	var parsed sendEmailResponse
	if len(respBody) > 0 && json.Unmarshal(respBody, &parsed) == nil {
		result.ID = parsed.ID
		if parsed.Message != "" {
			result.Reason = parsed.Message
		} else if parsed.Name != "" {
			result.Reason = parsed.Name
		}
	}

	if !result.Success {
		if result.Reason == "" {
			result.Reason = raw
		}
		if result.Reason == "" {
			result.Reason = http.StatusText(resp.StatusCode)
		}
		return result, fmt.Errorf("resend send rejected: %s", result.Summary())
	}

	if result.Reason == "" {
		result.Reason = "accepted"
	}

	return result, nil
}
