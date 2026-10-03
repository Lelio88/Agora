package httpx

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestRouter(t *testing.T) {
	tests := []struct {
		name     string
		method   string
		path     string
		wantCode int
	}{
		{name: "health check answers GET", method: http.MethodGet, path: "/healthz", wantCode: http.StatusOK},
		{name: "health check refuses POST", method: http.MethodPost, path: "/healthz", wantCode: http.StatusMethodNotAllowed},
		{name: "unknown path is not found", method: http.MethodGet, path: "/nope", wantCode: http.StatusNotFound},
		{
			name:   "discord interactions are not mounted without a public key",
			method: http.MethodPost, path: "/discord/interactions", wantCode: http.StatusNotFound,
		},
		{
			name:   "the auth gate is not mounted without its upstream",
			method: http.MethodPost, path: "/auth/v1/signup", wantCode: http.StatusNotFound,
		},
		{
			name:   "the assistant server is not mounted without its configuration",
			method: http.MethodPost, path: "/mcp", wantCode: http.StatusNotFound,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rec := httptest.NewRecorder()

			NewRouter(Handlers{}).ServeHTTP(rec, httptest.NewRequest(tt.method, tt.path, nil))

			if rec.Code != tt.wantCode {
				t.Errorf("status = %d, want %d", rec.Code, tt.wantCode)
			}
		})
	}
}

func answering(code int) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(code) })
}

func TestRouterMountsTheAuthGateGuardAndAssistant(t *testing.T) {
	const gate, guard, mcp, meta = http.StatusTeapot, http.StatusAccepted, http.StatusCreated, http.StatusNonAuthoritativeInfo
	router := NewRouter(Handlers{
		AuthGate: answering(gate), AuthGuard: answering(guard),
		MCP: answering(mcp), ResourceMetadata: answering(meta),
	})
	tests := []struct {
		name, method, path string
		wantCode           int
	}{
		{name: "sign-up", method: http.MethodPost, path: "/auth/v1/signup", wantCode: gate},
		{name: "forgotten password", method: http.MethodPost, path: "/auth/v1/recover", wantCode: gate},
		{name: "code resent", method: http.MethodPost, path: "/auth/v1/resend", wantCode: gate},
		{name: "token", method: http.MethodPost, path: "/auth/v1/token", wantCode: gate},
		{name: "only POST", method: http.MethodGet, path: "/auth/v1/signup", wantCode: http.StatusMethodNotAllowed},
		{name: "account update goes through the guard first", method: http.MethodPut, path: "/auth/v1/user", wantCode: guard},
		{name: "account read", method: http.MethodGet, path: "/auth/v1/user", wantCode: guard},
		{name: "identity linking", method: http.MethodGet, path: "/auth/v1/user/identities/authorize", wantCode: guard},
		{name: "identity unlinking", method: http.MethodDelete, path: "/auth/v1/user/identities/abc", wantCode: guard},
		{name: "granted accesses", method: http.MethodGet, path: "/auth/v1/user/oauth/grants", wantCode: guard},
		{name: "sign-out", method: http.MethodPost, path: "/auth/v1/logout", wantCode: guard},
		{name: "factors", method: http.MethodPost, path: "/auth/v1/factors", wantCode: guard},
		{name: "a factor", method: http.MethodPost, path: "/auth/v1/factors/abc/verify", wantCode: guard},
		{name: "reauthentication", method: http.MethodGet, path: "/auth/v1/reauthenticate", wantCode: guard},
		{name: "oauth consent", method: http.MethodPost, path: "/auth/v1/oauth/authorizations/abc/consent", wantCode: guard},
		{name: "nothing else of GoTrue", method: http.MethodGet, path: "/auth/v1/settings", wantCode: http.StatusNotFound},
		{name: "mcp", method: http.MethodPost, path: "/mcp", wantCode: mcp},
		{name: "resource metadata", method: http.MethodGet, path: "/.well-known/oauth-protected-resource/mcp", wantCode: meta},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rec := httptest.NewRecorder()

			router.ServeHTTP(rec, httptest.NewRequest(tt.method, tt.path, nil))

			if rec.Code != tt.wantCode {
				t.Errorf("status = %d, want %d", rec.Code, tt.wantCode)
			}
		})
	}
}
