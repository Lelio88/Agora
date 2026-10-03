package authgate

import (
	"encoding/base64"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
)

func jwtWith(claims map[string]any) string {
	header := base64.RawURLEncoding.EncodeToString([]byte(`{"alg":"HS256","typ":"JWT"}`))
	payload, _ := json.Marshal(claims)
	return header + "." + base64.RawURLEncoding.EncodeToString(payload) + ".sig"
}

var (
	appToken       = jwtWith(map[string]any{"sub": "u1", "role": "authenticated"})
	assistantToken = jwtWith(map[string]any{"sub": "u1", "role": "authenticated", "client_id": "c1"})
)

// relayed est ce que le faux GoTrue a reçu.
type relayed struct {
	method, path, query, auth, forwarded, body string
}

func fakeUpstream(t *testing.T) (*httptest.Server, func() []relayed) {
	t.Helper()
	var mu sync.Mutex
	var got []relayed
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		mu.Lock()
		got = append(got, relayed{r.Method, r.URL.Path, r.URL.RawQuery, r.Header.Get("Authorization"),
			r.Header.Get("X-Forwarded-For"), string(body)})
		mu.Unlock()
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"ok":true}`))
	}))
	t.Cleanup(srv.Close)
	return srv, func() []relayed {
		mu.Lock()
		defer mu.Unlock()
		return append([]relayed(nil), got...)
	}
}

func newTestGuard(t *testing.T, upstream string) *Guard {
	t.Helper()
	gate, err := New(Options{Upstream: upstream})
	if err != nil {
		t.Fatal(err)
	}
	guard, err := NewGuard(upstream, gate, nil)
	if err != nil {
		t.Fatal(err)
	}
	return guard
}

func TestGuardRefusesAssistantTokens(t *testing.T) {
	upstream, received := fakeUpstream(t)
	guard := newTestGuard(t, upstream.URL)
	tests := []struct{ name, method, path, body string }{
		{name: "account read (e-mail)", method: http.MethodGet, path: "/auth/v1/user"},
		{name: "password change", method: http.MethodPut, path: "/auth/v1/user", body: `{"password":"nouveau-secret"}`},
		{name: "identity linking", method: http.MethodGet, path: "/auth/v1/user/identities/authorize?provider=discord"},
		{name: "identity unlinking", method: http.MethodDelete, path: "/auth/v1/user/identities/i1"},
		{name: "granted accesses", method: http.MethodGet, path: "/auth/v1/user/oauth/grants"},
		{name: "global sign-out", method: http.MethodPost, path: "/auth/v1/logout"},
		{name: "factor enrolment", method: http.MethodPost, path: "/auth/v1/factors"},
		{name: "reauthentication", method: http.MethodGet, path: "/auth/v1/reauthenticate"},
		{name: "granting another access", method: http.MethodPost, path: "/auth/v1/oauth/authorizations/a1/consent", body: `{"action":"approve"}`},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(tt.method, tt.path, strings.NewReader(tt.body))
			req.Header.Set("Authorization", "Bearer "+assistantToken)
			rec := httptest.NewRecorder()

			guard.ServeHTTP(rec, req)

			if rec.Code != http.StatusForbidden || !strings.Contains(rec.Body.String(), "assistant_forbidden") {
				t.Fatalf("statut %d, corps %s", rec.Code, rec.Body)
			}
		})
	}
	if got := received(); len(got) != 0 {
		t.Fatalf("GoTrue a reçu %d requête(s) d'un assistant : %+v", len(got), got)
	}
}

func TestGuardRelaysTheApplication(t *testing.T) {
	upstream, received := fakeUpstream(t)
	guard := newTestGuard(t, upstream.URL)

	req := httptest.NewRequest(http.MethodGet, "/auth/v1/user/identities/authorize?provider=discord&skip_http_redirect=true", nil)
	req.Header.Set("Authorization", "Bearer "+appToken)
	req.Header.Set("X-Forwarded-For", "203.0.113.7")
	rec := httptest.NewRecorder()
	guard.ServeHTTP(rec, req)

	got := received()
	if rec.Code != http.StatusOK || len(got) != 1 {
		t.Fatalf("statut %d, relais %+v", rec.Code, got)
	}
	r := got[0]
	if r.path != "/user/identities/authorize" || r.query != "provider=discord&skip_http_redirect=true" ||
		r.auth != "Bearer "+appToken || r.forwarded != "203.0.113.7" {
		t.Fatalf("relais = %+v : chemin sans préfixe, requête, jeton et X-Forwarded-For intacts", r)
	}

	anonymous := httptest.NewRecorder()
	guard.ServeHTTP(anonymous, httptest.NewRequest(http.MethodPost, "/auth/v1/logout", nil))
	if anonymous.Code != http.StatusOK || len(received()) != 2 {
		t.Fatalf("sans jeton, GoTrue juge : statut %d", anonymous.Code)
	}
}

func TestGuardHandsAccountUpdatesToTheGate(t *testing.T) {
	upstream, received := fakeUpstream(t)
	guard := newTestGuard(t, upstream.URL)

	emailChange := httptest.NewRequest(http.MethodPut, "/auth/v1/user", strings.NewReader(`{"email":"autre@test.local"}`))
	emailChange.Header.Set("Authorization", "Bearer "+appToken)
	rec := httptest.NewRecorder()
	guard.ServeHTTP(rec, emailChange)
	if rec.Code != http.StatusUnprocessableEntity || len(received()) != 0 {
		t.Fatalf("changement d'adresse : statut %d, relais %d", rec.Code, len(received()))
	}

	password := httptest.NewRequest(http.MethodPut, "/auth/v1/user", strings.NewReader(`{"password":"nouveau-secret"}`))
	password.Header.Set("Authorization", "Bearer "+appToken)
	rec = httptest.NewRecorder()
	guard.ServeHTTP(rec, password)
	if got := received(); rec.Code != http.StatusOK || len(got) != 1 || got[0].path != "/user" || got[0].method != http.MethodPut {
		t.Fatalf("mot de passe de l'app : statut %d, relais %+v", rec.Code, got)
	}
}

func TestGuardAnswersWhenGoTrueIsDown(t *testing.T) {
	upstream, _ := fakeUpstream(t)
	guard := newTestGuard(t, upstream.URL)
	upstream.Close()
	rec := httptest.NewRecorder()
	guard.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/auth/v1/user", nil))
	if rec.Code != http.StatusBadGateway {
		t.Fatalf("statut %d", rec.Code)
	}
}
