package discord

import (
	"context"
	"crypto/ed25519"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
	"time"
)

// Interaction signée comme Discord le fait : signature Ed25519 de
// l'horodatage concaténé au corps.
func signed(t *testing.T, key ed25519.PrivateKey, at time.Time, body string) *http.Request {
	t.Helper()
	timestamp := strconv.FormatInt(at.Unix(), 10)
	signature := ed25519.Sign(key, []byte(timestamp+body))
	req := httptest.NewRequest(http.MethodPost, "/discord/interactions", strings.NewReader(body))
	req.Header.Set("X-Signature-Ed25519", hex.EncodeToString(signature))
	req.Header.Set("X-Signature-Timestamp", timestamp)
	return req
}

func testHandler(t *testing.T, commands map[string]CommandFunc, now time.Time) (*Handler, ed25519.PrivateKey) {
	t.Helper()
	public, private, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("clés de test : %v", err)
	}
	h, err := NewHandler(hex.EncodeToString(public), commands, func() time.Time { return now })
	if err != nil {
		t.Fatalf("NewHandler : %v", err)
	}
	return h, private
}

func TestNewHandlerRejectsAnInvalidKey(t *testing.T) {
	tests := []struct {
		name string
		key  string
	}{
		{name: "empty", key: ""},
		{name: "not hexadecimal", key: strings.Repeat("z", 64)},
		{name: "too short", key: hex.EncodeToString([]byte("trop court"))},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if _, err := NewHandler(tt.key, nil, time.Now); err == nil {
				t.Fatal("une clé publique invalide doit faire échouer le démarrage")
			}
		})
	}
}

func TestHandlerAnswersPing(t *testing.T) {
	now := time.Unix(1790000000, 0)
	h, key := testHandler(t, nil, now)
	rec := httptest.NewRecorder()

	h.ServeHTTP(rec, signed(t, key, now, `{"type":1}`))

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200 (corps : %s)", rec.Code, rec.Body)
	}
	var got struct {
		Type int `json:"type"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &got); err != nil {
		t.Fatalf("réponse illisible : %v", err)
	}
	if got.Type != 1 {
		t.Errorf("type = %d, want 1 (PONG)", got.Type)
	}
}

func TestHandlerRefusesWhatDiscordDidNotSign(t *testing.T) {
	now := time.Unix(1790000000, 0)
	h, key := testHandler(t, nil, now)

	tests := []struct {
		name     string
		request  func() *http.Request
		wantCode int
	}{
		{
			name: "sans signature",
			request: func() *http.Request {
				return httptest.NewRequest(http.MethodPost, "/discord/interactions", strings.NewReader(`{"type":1}`))
			},
			wantCode: http.StatusUnauthorized,
		},
		{
			name: "signature d'un autre corps",
			request: func() *http.Request {
				req := signed(t, key, now, `{"type":1}`)
				req.Body = io.NopCloser(strings.NewReader(`{"type":2}`))
				return req
			},
			wantCode: http.StatusUnauthorized,
		},
		{
			name: "signature qui n'est pas de l'hexadécimal",
			request: func() *http.Request {
				req := signed(t, key, now, `{"type":1}`)
				req.Header.Set("X-Signature-Ed25519", "pas-de-l-hexa")
				return req
			},
			wantCode: http.StatusUnauthorized,
		},
		{
			name: "horodatage trop ancien (rejeu)",
			request: func() *http.Request {
				return signed(t, key, now.Add(-10*time.Minute), `{"type":1}`)
			},
			wantCode: http.StatusUnauthorized,
		},
		{
			name: "horodatage dans le futur",
			request: func() *http.Request {
				return signed(t, key, now.Add(10*time.Minute), `{"type":1}`)
			},
			wantCode: http.StatusUnauthorized,
		},
		{
			name: "horodatage illisible",
			request: func() *http.Request {
				req := signed(t, key, now, `{"type":1}`)
				req.Header.Set("X-Signature-Timestamp", "hier")
				return req
			},
			wantCode: http.StatusUnauthorized,
		},
		{
			name: "corps démesuré",
			request: func() *http.Request {
				return signed(t, key, now, `{"type":1,"x":"`+strings.Repeat("a", maxBody)+`"}`)
			},
			wantCode: http.StatusRequestEntityTooLarge,
		},
		{
			name: "corps signé mais illisible",
			request: func() *http.Request {
				return signed(t, key, now, `{"type":`)
			},
			wantCode: http.StatusBadRequest,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rec := httptest.NewRecorder()

			h.ServeHTTP(rec, tt.request())

			if rec.Code != tt.wantCode {
				t.Errorf("status = %d, want %d (corps : %s)", rec.Code, tt.wantCode, rec.Body)
			}
		})
	}
}

func TestHandlerRunsACommand(t *testing.T) {
	now := time.Unix(1790000000, 0)
	var seen Interaction
	commands := map[string]CommandFunc{
		"agenda": func(_ context.Context, in Interaction) Reply {
			seen = in
			return Reply{Content: Text(in.Locale, "Ton agenda", "Your agenda")}
		},
	}
	h, key := testHandler(t, commands, now)
	body := `{"type":2,"locale":"fr","guild_id":"42","channel_id":"7",` +
		`"data":{"name":"agenda"},"member":{"user":{"id":"u1"}}}`
	rec := httptest.NewRecorder()

	h.ServeHTTP(rec, signed(t, key, now, body))

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200 (corps : %s)", rec.Code, rec.Body)
	}
	var got struct {
		Type int `json:"type"`
		Data struct {
			Content string `json:"content"`
			Flags   int    `json:"flags"`
		} `json:"data"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &got); err != nil {
		t.Fatalf("réponse illisible : %v", err)
	}
	if got.Type != 4 {
		t.Errorf("type = %d, want 4 (message)", got.Type)
	}
	if got.Data.Content != "Ton agenda" {
		t.Errorf("contenu = %q, want la réponse française", got.Data.Content)
	}
	// 64 = EPHEMERAL : une réponse de commande ne doit être visible que du
	// demandeur (§6 de l'architecture).
	if got.Data.Flags != 64 {
		t.Errorf("flags = %d, want 64 (visible du seul demandeur)", got.Data.Flags)
	}
	if seen.UserID != "u1" || seen.GuildID != "42" || seen.ChannelID != "7" {
		t.Errorf("interaction transmise = %+v", seen)
	}
}

func TestHandlerAnswersAnUnknownCommandWithoutFailing(t *testing.T) {
	now := time.Unix(1790000000, 0)
	h, key := testHandler(t, map[string]CommandFunc{}, now)
	rec := httptest.NewRecorder()

	h.ServeHTTP(rec, signed(t, key, now, `{"type":2,"locale":"en-US","data":{"name":"inconnue"},"user":{"id":"u2"}}`))

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), "command") {
		t.Errorf("réponse = %s, want un message en anglais (locale en-US)", rec.Body)
	}
}

func TestHandlerIgnoresInteractionsItDoesNotHandle(t *testing.T) {
	now := time.Unix(1790000000, 0)
	h, key := testHandler(t, nil, now)
	rec := httptest.NewRecorder()

	// 3 = composant de message (bouton) : aucun n'est publié pour l'instant.
	h.ServeHTTP(rec, signed(t, key, now, `{"type":3,"data":{"custom_id":"x"}}`))

	if rec.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want 400", rec.Code)
	}
}

func TestTextPicksTheLocale(t *testing.T) {
	tests := []struct {
		name   string
		locale string
		want   string
	}{
		{name: "français", locale: "fr", want: "oui"},
		{name: "autre variante française", locale: "fr-CA", want: "oui"},
		{name: "anglais", locale: "en-GB", want: "yes"},
		{name: "langue inconnue : anglais", locale: "de", want: "yes"},
		{name: "sans locale : anglais", locale: "", want: "yes"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Text(tt.locale, "oui", "yes"); got != tt.want {
				t.Errorf("Text(%q) = %q, want %q", tt.locale, got, tt.want)
			}
		})
	}
}

func ExampleNewHandler() {
	h, err := NewHandler(strings.Repeat("00", ed25519.PublicKeySize), map[string]CommandFunc{
		"dispo": func(context.Context, Interaction) Reply { return Reply{Content: "…"} },
	}, time.Now)
	fmt.Println(h != nil, err)
	// Output: true <nil>
}
