package nobu

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"
)

type Client struct {
	BaseURL, ClientID, ClientSecret, PartnerID, MerchantID, SubMerchantID, StoreID, TerminalID, PrivateKeyPEM string
	PublicKeyPEM                                                                                              string
	ChannelID                                                                                                 string
	HTTPClient                                                                                                *http.Client
	mu                                                                                                        sync.Mutex
	token                                                                                                     string
	tokenExpiresAt                                                                                            time.Time
}

type Amount struct {
	Value    string `json:"value"`
	Currency string `json:"currency"`
}
type GenerateQRRequest struct {
	PartnerReferenceNo string `json:"partnerReferenceNo"`
	Amount             Amount `json:"amount"`
	MerchantID         string `json:"merchantId"`
	SubMerchantID      string `json:"subMerchantId,omitempty"`
	StoreID            string `json:"storeId"`
	TerminalID         string `json:"terminalId"`
	AdditionalInfo     struct {
		ValidTime string `json:"validTime"`
		Tip       string `json:"tip"`
		QRType    string `json:"qrType"`
	} `json:"additionalInfo"`
}
type GenerateQRResponse struct {
	ResponseCode       string `json:"responseCode"`
	ResponseMessage    string `json:"responseMessage"`
	ReferenceNo        string `json:"referenceNo"`
	PartnerReferenceNo string `json:"partnerReferenceNo"`
	QRContent          string `json:"qrContent"`
	QRURL              string `json:"qrUrl"`
	QRImage            string `json:"qrImage"`
	MerchantName       string `json:"merchantName"`
	StoreID            string `json:"storeId"`
	TerminalID         string `json:"terminalId"`
}
type QueryRequest struct {
	OriginalPartnerReferenceNo string `json:"originalPartnerReferenceNo"`
	OriginalReferenceNo        string `json:"originalReferenceNo,omitempty"`
	ServiceCode                string `json:"serviceCode"`
	MerchantID                 string `json:"merchantId"`
	SubMerchantID              string `json:"subMerchantId,omitempty"`
	ExternalStoreID            string `json:"externalStoreId"`
	AdditionalInfo             struct {
		POSID string `json:"posId"`
	} `json:"additionalInfo"`
}
type QueryResponse struct {
	ResponseCode               string `json:"responseCode"`
	ResponseMessage            string `json:"responseMessage"`
	OriginalReferenceNo        string `json:"originalReferenceNo"`
	OriginalPartnerReferenceNo string `json:"originalPartnerReferenceNo"`
	LatestTransactionStatus    string `json:"latestTransactionStatus"`
	TransactionStatusDesc      string `json:"transactionStatusDesc"`
	PaidTime                   string `json:"paidTime"`
	Amount                     Amount `json:"amount"`
	AdditionalInfo             struct {
		RetrievalReferenceNo string `json:"retrievalReferenceNo"`
		PaymentReferenceNo   string `json:"paymentReferenceNo"`
		NetAmount            string `json:"nettAmount"`
	} `json:"additionalInfo"`
}

func (c *Client) httpClient() *http.Client {
	if c.HTTPClient != nil {
		return c.HTTPClient
	}
	return &http.Client{Timeout: 15 * time.Second}
}

func (c *Client) Token(clientIP string) (string, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.token != "" && time.Now().Before(c.tokenExpiresAt.Add(-30*time.Second)) {
		return c.token, nil
	}
	ts := time.Now().Format("2006-01-02T15:04:05-07:00")
	sig, err := SignToken(c.PrivateKeyPEM, c.ClientID, ts)
	if err != nil {
		return "", err
	}
	body := []byte(fmt.Sprintf(`{"grantType":"client_credentials","additionalInfo":{"partnerId":%q}}`, c.PartnerID))
	var out struct {
		ResponseCode    string `json:"responseCode"`
		ResponseMessage string `json:"responseMessage"`
		AccessToken     string `json:"accessToken"`
		ExpiresIn       string `json:"expiresIn"`
	}
	if err := c.do("/v2.0/access-token/b2b/", body, map[string]string{"X-CLIENT-KEY": c.ClientID, "X-SIGNATURE": sig, "X-TIMESTAMP": ts, "X-IP-ADDRESS": clientIP, "CHANNEL-ID": c.ChannelID}, &out); err != nil {
		return "", err
	}
	if out.AccessToken == "" {
		return "", fmt.Errorf("Nobu token failed: %s %s", out.ResponseCode, out.ResponseMessage)
	}
	seconds := 900
	fmt.Sscanf(out.ExpiresIn, "%d", &seconds)
	c.token, c.tokenExpiresAt = out.AccessToken, time.Now().Add(time.Duration(seconds)*time.Second)
	return c.token, nil
}

func (c *Client) GenerateQR(req GenerateQRRequest, externalID, clientIP string) (GenerateQRResponse, error) {
	path := "/v1.2/qr/qr-mpm-generate/"
	body, err := json.Marshal(req)
	if err != nil {
		return GenerateQRResponse{}, err
	}
	var out GenerateQRResponse
	err = c.postSigned(path, body, externalID, clientIP, &out)
	return out, err
}

func (c *Client) QueryPayment(req QueryRequest, externalID, clientIP string) (QueryResponse, error) {
	path := "/v1.2/qr/qr-mpm-query/"
	body, err := json.Marshal(req)
	if err != nil {
		return QueryResponse{}, err
	}
	var out QueryResponse
	err = c.postSigned(path, body, externalID, clientIP, &out)
	return out, err
}

func (c *Client) postSigned(path string, body []byte, externalID, clientIP string, out any) error {
	token, err := c.Token(clientIP)
	if err != nil {
		return err
	}
	ts := time.Now().Format("2006-01-02T15:04:05-07:00")
	sig := SignTransaction(c.ClientSecret, "POST", path, token, ts, string(body))
	headers := map[string]string{"Authorization": "Bearer " + token, "X-PARTNER-ID": c.PartnerID, "X-SIGNATURE": sig, "X-TIMESTAMP": ts, "X-EXTERNAL-ID": externalID, "X-IP-ADDRESS": clientIP, "CHANNEL-ID": c.ChannelID}
	return c.do(path, body, headers, out)
}

func (c *Client) do(path string, body []byte, headers map[string]string, out any) error {
	url := strings.TrimRight(c.BaseURL, "/") + path
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	resp, err := c.httpClient().Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		return err
	}
	if resp.StatusCode >= 500 {
		return fmt.Errorf("Nobu HTTP %d", resp.StatusCode)
	}
	return json.Unmarshal(raw, out)
}
