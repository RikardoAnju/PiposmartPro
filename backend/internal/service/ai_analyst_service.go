package service

import (
	"bufio"
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/RikardoAnju/PiposmartPro/internal/config"
)

// AIAnalystService: chat analis data. Model (Gemini) mengusulkan SQL lewat tool
// run_sql; backend menjalankannya di koneksi READ-ONLY dengan guardrail, lalu
// hasilnya dikembalikan ke model untuk dirangkum. History disimpan per sesi
// sehingga context window "hidup" lintas pesan.
type AIAnalystService struct {
	roDB   *sql.DB // koneksi read-only (user ayocuci_ai_ro, SELECT saja)
	apiKey string
	model  string

	mu       sync.Mutex
	sessions map[string]*aiSession

	schemaMu   sync.Mutex
	schemaText string
	schemaAt   time.Time
}

type aiSession struct {
	contents []map[string]any
	lastUsed time.Time
}

const (
	aiMaxToolLoops   = 6
	aiRowLimit       = 500
	aiQueryTimeout   = 12 * time.Second
	aiSessionTTL     = 2 * time.Hour
	aiSchemaTTL      = 1 * time.Hour
	aiGeminiEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent"
)

func NewAIAnalystService() (*AIAnalystService, error) {
	dsn := strings.TrimSpace(config.GetEnv("AI_DB_DSN", ""))
	if dsn == "" {
		return nil, fmt.Errorf("AI_DB_DSN belum diset")
	}
	apiKey := strings.TrimSpace(config.GetEnv("GEMINI_API_KEY", ""))
	if apiKey == "" {
		return nil, fmt.Errorf("GEMINI_API_KEY belum diset")
	}
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(4)
	db.SetConnMaxIdleTime(5 * time.Minute)

	return &AIAnalystService{
		roDB:     db,
		apiKey:   apiKey,
		model:    config.GetEnv("GEMINI_MODEL", "gemini-3.6-flash"),
		sessions: map[string]*aiSession{},
	}, nil
}

// AskResult dikirim balik ke controller.
type AskResult struct {
	Answer    string   `json:"answer"`
	SQLs      []string `json:"sqls"`
	SessionID string   `json:"session_id"`
}

func (s *AIAnalystService) Ask(sessionID, message string) (AskResult, error) {
	sess := s.getSession(sessionID)

	// Tambahkan pesan user ke history.
	sess.contents = append(sess.contents, map[string]any{
		"role":  "user",
		"parts": []any{map[string]any{"text": message}},
	})

	var usedSQL []string
	for loop := 0; loop < aiMaxToolLoops; loop++ {
		respContent, err := s.callGemini(sess.contents)
		if err != nil {
			return AskResult{}, err
		}
		// Append konten model APA ADANYA (mempertahankan thoughtSignature).
		sess.contents = append(sess.contents, respContent)

		parts, _ := respContent["parts"].([]any)
		fcName, fcArgs, hasFC := extractFunctionCall(parts)
		if !hasFC {
			answer := extractText(parts)
			sess.lastUsed = time.Now()
			return AskResult{Answer: answer, SQLs: usedSQL, SessionID: sessionID}, nil
		}

		// Jalankan tool run_sql.
		query, _ := fcArgs["query"].(string)
		usedSQL = append(usedSQL, query)
		toolResp := s.runSQLTool(query)

		sess.contents = append(sess.contents, map[string]any{
			"role": "user",
			"parts": []any{map[string]any{
				"functionResponse": map[string]any{
					"name":     fcName,
					"response": toolResp,
				},
			}},
		})
	}
	return AskResult{}, fmt.Errorf("melebihi batas langkah query, coba persempit pertanyaan")
}

// AskStream: sama seperti Ask, tapi mem-forward jawaban secara streaming
// lewat callback emit (event: "text" delta, "status", "done", "error").
func (s *AIAnalystService) AskStream(sessionID, message string, emit func(evt string, payload map[string]any)) {
	sess := s.getSession(sessionID)
	sess.contents = append(sess.contents, map[string]any{
		"role": "user", "parts": []any{map[string]any{"text": message}},
	})

	var usedSQL []string
	for loop := 0; loop < aiMaxToolLoops; loop++ {
		modelContent, fcName, fcArgs, hasFC, err := s.streamTurn(sess.contents, func(delta string) {
			emit("text", map[string]any{"delta": delta})
		})
		if err != nil {
			emit("error", map[string]any{"message": err.Error()})
			return
		}
		sess.contents = append(sess.contents, modelContent)

		if !hasFC {
			sess.lastUsed = time.Now()
			emit("done", map[string]any{"sqls": usedSQL, "session_id": sessionID})
			return
		}
		query, _ := fcArgs["query"].(string)
		usedSQL = append(usedSQL, query)
		emit("status", map[string]any{"message": "Menjalankan query..."})
		toolResp := s.runSQLTool(query)
		sess.contents = append(sess.contents, map[string]any{
			"role": "user",
			"parts": []any{map[string]any{
				"functionResponse": map[string]any{"name": fcName, "response": toolResp},
			}},
		})
	}
	emit("error", map[string]any{"message": "melebihi batas langkah query, coba persempit pertanyaan"})
}

func (s *AIAnalystService) streamTurn(contents []map[string]any, onDelta func(string)) (map[string]any, string, map[string]any, bool, error) {
	body := s.requestBody(contents)
	raw, _ := json.Marshal(body)

	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()
	url := fmt.Sprintf("https://generativelanguage.googleapis.com/v1beta/models/%s:streamGenerateContent?alt=sse", s.model)
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(raw))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-goog-api-key", s.apiKey)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, "", nil, false, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		d, _ := io.ReadAll(resp.Body)
		return nil, "", nil, false, fmt.Errorf("gemini stream error %d: %s", resp.StatusCode, truncate(string(d), 300))
	}

	var textBuf strings.Builder
	var fcPart map[string]any
	var fcName string
	var fcArgs map[string]any

	sc := bufio.NewScanner(resp.Body)
	sc.Buffer(make([]byte, 0, 64*1024), 4*1024*1024)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if !strings.HasPrefix(line, "data:") {
			continue
		}
		payload := strings.TrimSpace(strings.TrimPrefix(line, "data:"))
		if payload == "" || payload == "[DONE]" {
			continue
		}
		var chunk struct {
			Candidates []struct {
				Content map[string]any `json:"content"`
			} `json:"candidates"`
		}
		if json.Unmarshal([]byte(payload), &chunk) != nil || len(chunk.Candidates) == 0 {
			continue
		}
		parts, _ := chunk.Candidates[0].Content["parts"].([]any)
		for _, p := range parts {
			pm, ok := p.(map[string]any)
			if !ok {
				continue
			}
			if t, ok := pm["text"].(string); ok && t != "" {
				textBuf.WriteString(t)
				onDelta(t)
			}
			if fc, ok := pm["functionCall"].(map[string]any); ok {
				fcPart = pm // verbatim (termasuk thoughtSignature)
				fcName, _ = fc["name"].(string)
				fcArgs, _ = fc["args"].(map[string]any)
				if fcArgs == nil {
					fcArgs = map[string]any{}
				}
			}
		}
	}
	if err := sc.Err(); err != nil {
		return nil, "", nil, false, err
	}

	if fcPart != nil {
		return map[string]any{"role": "model", "parts": []any{fcPart}}, fcName, fcArgs, true, nil
	}
	return map[string]any{"role": "model", "parts": []any{map[string]any{"text": textBuf.String()}}}, "", nil, false, nil
}

// requestBody membangun payload Gemini (dipakai stream & non-stream).
func (s *AIAnalystService) requestBody(contents []map[string]any) map[string]any {
	return map[string]any{
		"systemInstruction": map[string]any{
			"parts": []any{map[string]any{"text": s.systemPrompt()}},
		},
		"contents": contents,
		"tools": []any{map[string]any{
			"functionDeclarations": []any{map[string]any{
				"name":        "run_sql",
				"description": "Jalankan satu query SELECT read-only ke database MySQL AyoCuci dan kembalikan barisnya.",
				"parameters": map[string]any{
					"type": "object",
					"properties": map[string]any{
						"query": map[string]any{"type": "string", "description": "Query SELECT MySQL yang valid."},
					},
					"required": []any{"query"},
				},
			}},
		}},
	}
}

// ── Gemini REST ──────────────────────────────────────────────────────────
func (s *AIAnalystService) callGemini(contents []map[string]any) (map[string]any, error) {
	raw, _ := json.Marshal(s.requestBody(contents))

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	url := fmt.Sprintf(aiGeminiEndpoint, s.model)
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(raw))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-goog-api-key", s.apiKey)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("gemini error %d: %s", resp.StatusCode, truncate(string(data), 300))
	}

	var parsed struct {
		Candidates []struct {
			Content map[string]any `json:"content"`
		} `json:"candidates"`
	}
	if err := json.Unmarshal(data, &parsed); err != nil {
		return nil, err
	}
	if len(parsed.Candidates) == 0 || parsed.Candidates[0].Content == nil {
		return nil, fmt.Errorf("respon AI kosong")
	}
	return parsed.Candidates[0].Content, nil
}

// ── Tool run_sql (guardrail) ─────────────────────────────────────────────
var (
	reMultiStmt = regexp.MustCompile(`;\s*\S`)
	reForbidden = regexp.MustCompile(`(?i)\b(insert|update|delete|drop|alter|create|grant|revoke|truncate|replace|rename|call|lock|set|use|into\s+outfile|load_file)\b`)
	reHasLimit  = regexp.MustCompile(`(?i)\blimit\b`)
)

func (s *AIAnalystService) runSQLTool(query string) map[string]any {
	q := strings.TrimSpace(strings.TrimRight(strings.TrimSpace(query), ";"))
	low := strings.ToLower(q)

	if q == "" {
		return map[string]any{"error": "query kosong"}
	}
	if !strings.HasPrefix(low, "select") && !strings.HasPrefix(low, "with") {
		return map[string]any{"error": "hanya query SELECT yang diizinkan"}
	}
	if reMultiStmt.MatchString(q) {
		return map[string]any{"error": "hanya satu statement yang diizinkan"}
	}
	if reForbidden.MatchString(q) {
		return map[string]any{"error": "query mengandung operasi yang tidak diizinkan (read-only)"}
	}
	if !reHasLimit.MatchString(q) {
		q = q + fmt.Sprintf(" LIMIT %d", aiRowLimit)
	}

	ctx, cancel := context.WithTimeout(context.Background(), aiQueryTimeout)
	defer cancel()
	rows, err := s.roDB.QueryContext(ctx, q)
	if err != nil {
		return map[string]any{"error": err.Error()}
	}
	defer rows.Close()

	cols, _ := rows.Columns()
	out := make([]map[string]any, 0, 64)
	for rows.Next() {
		vals := make([]any, len(cols))
		ptrs := make([]any, len(cols))
		for i := range vals {
			ptrs[i] = &vals[i]
		}
		if err := rows.Scan(ptrs...); err != nil {
			return map[string]any{"error": err.Error()}
		}
		rec := map[string]any{}
		for i, c := range cols {
			if b, ok := vals[i].([]byte); ok {
				rec[c] = string(b)
			} else {
				rec[c] = vals[i]
			}
		}
		out = append(out, rec)
		if len(out) >= aiRowLimit {
			break
		}
	}
	return map[string]any{"row_count": len(out), "rows": out}
}

// ── Sesi ─────────────────────────────────────────────────────────────────
func (s *AIAnalystService) getSession(id string) *aiSession {
	s.mu.Lock()
	defer s.mu.Unlock()
	// eviksi kadaluarsa
	for k, v := range s.sessions {
		if time.Since(v.lastUsed) > aiSessionTTL {
			delete(s.sessions, k)
		}
	}
	sess, ok := s.sessions[id]
	if !ok {
		sess = &aiSession{lastUsed: time.Now()}
		s.sessions[id] = sess
	}
	return sess
}

func (s *AIAnalystService) systemPrompt() string {
	return `Kamu adalah AI Data Analyst untuk platform laundry SaaS "AyoCuci". Jawab pertanyaan admin tentang data dengan cara memanggil tool run_sql (query SELECT MySQL read-only), lalu rangkum hasilnya dalam Bahasa Indonesia yang ringkas + tabel bila relevan. JANGAN mengarang angka — selalu ambil dari hasil query. Jika query error, perbaiki dan coba lagi. Batasi hasil (LIMIT) dan hindari full scan berat.

== SKEMA TABEL (dibaca otomatis dari database, selalu terkini) ==
` + s.getSchemaText() + `

== CATATAN BISNIS (makna & relasi penting) ==
- ac_outlet = outlet/tenant. PRO (langganan aktif) = ot_activated_at IS NOT NULL; trial = ot_activated_at NULL, berakhir di ot_trial_at. Saldo koin = ot_koin. ot_status=1 aktif. Owner: ot_user -> ac_user.usr_id.
- ac_transaksi = transaksi laundry. Penjualan = SUM(tr_total) WHERE tr_status_order!='Batal'. tr_status_pembayaran: 'Lunas'/'Belum Lunas'. tr_outlet->ac_outlet.ot_id, tr_pelanggan->ac_pelanggan.pl_id.
- ac_pelanggan = pelanggan per outlet (pl_outlet->ot_id).
- ac_detail_transaksi = rincian layanan (dtr_transaksi->tr_id).
- ac_top_koin = top up koin. Berbayar sukses = tk_status IN('success','completed') AND tk_metode_bayar!='bonus'. tk_jumlah=koin, tk_total=rupiah, tk_metode_bayar in (transfer, midtrans, bonus).
- ac_history_koin = mutasi koin (hk_jenis_transaksi 'masuk'/'keluar'); IAP iOS muncul di sini via keterangan.
- ac_store_transactions = pembelian IAP iOS; hanya st_environment='Production' yang asli (Sandbox = test/reviewer).
- ac_transaksi_addons = pembelian add-on/fitur (ha_status='SUCCESS' = berhasil).
- ac_pegawai = karyawan outlet; aktif = pg_status=1 AND pg_deleted_at IS NULL.

Selalu JOIN via kolom relasi (ot_id, usr_id, pl_id, tr_id). Kolom tanggal bertipe datetime. Jika ragu nama kolom, cek dulu lewat query ke information_schema.`
}

// getSchemaText membaca daftar tabel+kolom dari information_schema (read-only),
// di-cache 1 jam. Perubahan struktur DB otomatis terbaca tanpa ubah kode.
func (s *AIAnalystService) getSchemaText() string {
	s.schemaMu.Lock()
	defer s.schemaMu.Unlock()
	if s.schemaText != "" && time.Since(s.schemaAt) < aiSchemaTTL {
		return s.schemaText
	}

	ctx, cancel := context.WithTimeout(context.Background(), aiQueryTimeout)
	defer cancel()
	rows, err := s.roDB.QueryContext(ctx, `
		SELECT table_name, column_name, column_type
		FROM information_schema.columns
		WHERE table_schema = DATABASE() AND table_name LIKE 'ac\_%'
		ORDER BY table_name, ordinal_position`)
	if err != nil {
		if s.schemaText != "" {
			return s.schemaText // pakai cache lama bila query gagal
		}
		return "(skema tidak dapat dibaca)"
	}
	defer rows.Close()

	cols := map[string][]string{}
	order := []string{}
	seen := map[string]bool{}
	for rows.Next() {
		var t, c, ct string
		if err := rows.Scan(&t, &c, &ct); err != nil {
			break
		}
		if !seen[t] {
			seen[t] = true
			order = append(order, t)
		}
		cols[t] = append(cols[t], c+" "+simpleType(ct))
	}

	var sb strings.Builder
	for _, t := range order {
		sb.WriteString("- ")
		sb.WriteString(t)
		sb.WriteString("(")
		sb.WriteString(strings.Join(cols[t], ", "))
		sb.WriteString(")\n")
	}
	s.schemaText = sb.String()
	s.schemaAt = time.Now()
	return s.schemaText
}

// simpleType meringkas column_type panjang jadi tipe dasar untuk hemat token.
func simpleType(ct string) string {
	ct = strings.ToLower(ct)
	switch {
	case strings.HasPrefix(ct, "varchar"), strings.HasPrefix(ct, "char"), strings.Contains(ct, "text"), strings.Contains(ct, "blob"), strings.Contains(ct, "enum"):
		return "str"
	case strings.HasPrefix(ct, "int"), strings.HasPrefix(ct, "bigint"), strings.HasPrefix(ct, "tinyint"), strings.HasPrefix(ct, "smallint"), strings.HasPrefix(ct, "double"), strings.HasPrefix(ct, "decimal"), strings.HasPrefix(ct, "float"):
		return "num"
	case strings.Contains(ct, "date"), strings.Contains(ct, "time"):
		return "datetime"
	default:
		return "str"
	}
}

// ── helpers ──────────────────────────────────────────────────────────────
func extractFunctionCall(parts []any) (string, map[string]any, bool) {
	for _, p := range parts {
		pm, ok := p.(map[string]any)
		if !ok {
			continue
		}
		if fc, ok := pm["functionCall"].(map[string]any); ok {
			name, _ := fc["name"].(string)
			args, _ := fc["args"].(map[string]any)
			if args == nil {
				args = map[string]any{}
			}
			return name, args, true
		}
	}
	return "", nil, false
}

func extractText(parts []any) string {
	var sb strings.Builder
	for _, p := range parts {
		if pm, ok := p.(map[string]any); ok {
			if t, ok := pm["text"].(string); ok {
				sb.WriteString(t)
			}
		}
	}
	return strings.TrimSpace(sb.String())
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}
