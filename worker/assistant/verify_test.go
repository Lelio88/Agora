package assistant

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"github.com/modelcontextprotocol/go-sdk/auth"
)

// fakeJWT fabrique un jeton à la charge voulue ; la signature est factice :
// c'est le faux GoTrue qui décide s'il l'accepte.
func fakeJWT(claims map[string]any) string {
	header := base64.RawURLEncoding.EncodeToString([]byte(`{"alg":"HS256","typ":"JWT"}`))
	payload, _ := json.Marshal(claims)
	return header + "." + base64.RawURLEncoding.EncodeToString(payload) + ".signature"
}

func assistantToken(sub string) string {
	return fakeJWT(map[string]any{"sub": sub, "client_id": "c1", "exp": time.Now().Add(time.Hour).Unix(), "scope": "email"})
}

// fakeGoTrue répond à GET /user selon status, et compte les appels.
func fakeGoTrue(t *testing.T, status int, userID string) (*httptest.Server, *atomic.Int32) {
	t.Helper()
	var calls atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		if r.URL.Path != "/user" || r.Header.Get("Authorization") == "" {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}
		w.WriteHeader(status)
		_, _ = w.Write([]byte(`{"id":"` + userID + `","code":"session_not_found"}`))
	}))
	t.Cleanup(srv.Close)
	return srv, &calls
}

func TestVerifier(t *testing.T) {
	tests := []struct {
		name        string
		token       string
		status      int
		goTrueUser  string
		wantUser    string
		invalid     bool
		askedGoTrue bool
	}{
		{name: "accepted_by_gotrue", token: assistantToken(ada), status: http.StatusOK, goTrueUser: ada, wantUser: ada, askedGoTrue: true},
		{name: "revoked_session", token: assistantToken(ada), status: http.StatusForbidden, invalid: true, askedGoTrue: true},
		{name: "expired_or_forged", token: assistantToken(ada), status: http.StatusUnauthorized, invalid: true, askedGoTrue: true},
		{name: "another_account", token: assistantToken(ada), status: http.StatusOK, goTrueUser: ben, invalid: true, askedGoTrue: true},
		{name: "an_app_session_is_not_an_assistant",
			token: fakeJWT(map[string]any{"sub": ada, "exp": time.Now().Add(time.Hour).Unix()}), invalid: true},
		{name: "garbage", token: "pas-un-jeton", invalid: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			srv, calls := fakeGoTrue(t, tt.status, tt.goTrueUser)
			info, err := NewVerifier(srv.URL, srv.Client())(context.Background(), tt.token, nil)
			if got := calls.Load() > 0; got != tt.askedGoTrue {
				t.Fatalf("GoTrue interrogé : %v, attendu %v", got, tt.askedGoTrue)
			}
			if tt.invalid {
				if !errors.Is(err, auth.ErrInvalidToken) {
					t.Fatalf("err = %v, attendu ErrInvalidToken (401)", err)
				}
				return
			}
			if err != nil || info.UserID != tt.wantUser || info.Expiration.IsZero() || info.Extra["client_id"] != "c1" {
				t.Fatalf("info = %+v, %v", info, err)
			}
		})
	}
}

func TestVerifierReportsAnOutageAsAnError(t *testing.T) {
	srv, _ := fakeGoTrue(t, http.StatusInternalServerError, "")
	_, err := NewVerifier(srv.URL, srv.Client())(context.Background(), assistantToken(ada), nil)
	if err == nil || errors.Is(err, auth.ErrInvalidToken) {
		t.Fatalf("une panne de GoTrue n'est pas un jeton invalide : %v", err)
	}
	slow := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		time.Sleep(200 * time.Millisecond)
	}))
	t.Cleanup(slow.Close)
	client := &http.Client{Timeout: 20 * time.Millisecond}
	if _, err := NewVerifier(slow.URL, client)(context.Background(), assistantToken(ada), nil); err == nil || errors.Is(err, auth.ErrInvalidToken) {
		t.Fatalf("GoTrue trop lent : err = %v", err)
	}
}
