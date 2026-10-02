package authgate

import (
	"bytes"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// Délais courts pour les tests ; la production garde les valeurs par défaut.
const (
	testEmailDelay  = 200 * time.Millisecond
	testSignInFloor = 150 * time.Millisecond
	// Marge sous laquelle une réponse passe pour « immédiate ».
	immediate = 80 * time.Millisecond
)

// upstreamCall est ce que GoTrue a reçu de la passerelle.
type upstreamCall struct {
	method, path, query string
	header              http.Header
	body                string
}

// fakeGoTrue répond par respond et note chaque appel sur calls.
func fakeGoTrue(t *testing.T, respond http.HandlerFunc) (*httptest.Server, chan upstreamCall) {
	t.Helper()
	calls := make(chan upstreamCall, 8)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		calls <- upstreamCall{r.Method, r.URL.Path, r.URL.RawQuery, r.Header.Clone(), string(body)}
		r.Body = io.NopCloser(bytes.NewReader(body))
		respond(w, r)
	}))
	t.Cleanup(srv.Close)
	return srv, calls
}

// next rend le prochain appel reçu par GoTrue, ou fait échouer le test.
func next(t *testing.T, calls chan upstreamCall) upstreamCall {
	t.Helper()
	select {
	case got := <-calls:
		return got
	case <-time.After(5 * time.Second):
		t.Fatal("GoTrue never received the request")
		return upstreamCall{}
	}
}

func reply(status int, body string, header ...string) http.HandlerFunc {
	return func(w http.ResponseWriter, _ *http.Request) {
		for i := 0; i+1 < len(header); i += 2 {
			w.Header().Set(header[i], header[i+1])
		}
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("X-Supabase-Api-Version", "2024-01-01")
		w.WriteHeader(status)
		_, _ = io.WriteString(w, body)
	}
}

func newGate(t *testing.T, upstream string) *Gate {
	t.Helper()
	g, err := New(Options{
		Upstream:    upstream,
		EmailDelay:  testEmailDelay,
		SignInFloor: testSignInFloor,
		Logger:      slog.New(slog.NewTextHandler(io.Discard, nil)),
	})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	return g
}

// call envoie une requête à la passerelle et rend la réponse et sa durée.
func call(g *Gate, method, target, body string, header ...string) (*httptest.ResponseRecorder, time.Duration) {
	req := httptest.NewRequest(method, target, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	for i := 0; i+1 < len(header); i += 2 {
		req.Header.Set(header[i], header[i+1])
	}
	rec := httptest.NewRecorder()
	start := time.Now()
	g.ServeHTTP(rec, req)
	return rec, time.Since(start)
}

func expectMasked(t *testing.T, rec *httptest.ResponseRecorder, elapsed time.Duration) {
	t.Helper()
	if rec.Code != http.StatusOK {
		t.Errorf("status = %d, want 200", rec.Code)
	}
	if got := rec.Body.String(); got != "{}" {
		t.Errorf("body = %q, want {}", got)
	}
	if got := rec.Header().Get("Content-Type"); got != "application/json" {
		t.Errorf("Content-Type = %q", got)
	}
	if got := rec.Header().Get("X-Supabase-Api-Version"); got != "2024-01-01" {
		t.Errorf("X-Supabase-Api-Version = %q", got)
	}
	if elapsed < testEmailDelay {
		t.Errorf("answered after %v, before the fixed delay %v", elapsed, testEmailDelay)
	}
}

func TestEmailEndpointsGiveTheSameAnswerWhateverGoTrueSays(t *testing.T) {
	upstreams := []struct {
		name    string
		respond http.HandlerFunc
	}{
		{"new_address_returns_the_user", reply(200, `{"id":"u1","email":"a@b.c","identities":[{"id":"i1"}]}`)},
		{"confirmed_account_returns_a_fake_user", reply(200, `{"id":"u2","email":"a@b.c","identities":[]}`)},
		{"address_already_mailed_this_minute", reply(429, `{"code":429,"error_code":"over_email_send_rate_limit","msg":"For security purposes, you can only request this after 52 seconds."}`)},
		{"unknown_rate_limit_is_masked_too", reply(429, `{"code":429,"error_code":"something_new","msg":"slow down"}`)},
		{"smtp_failure", reply(500, `{"code":500,"error_code":"unexpected_failure","msg":"Error sending confirmation email"}`)},
	}
	for _, path := range []string{"/auth/v1/signup", "/auth/v1/recover", "/auth/v1/resend"} {
		for _, up := range upstreams {
			t.Run(strings.TrimPrefix(path, "/auth/v1/")+"/"+up.name, func(t *testing.T) {
				srv, _ := fakeGoTrue(t, up.respond)

				rec, elapsed := call(newGate(t, srv.URL), http.MethodPost, path, `{"email":"a@b.c"}`)

				expectMasked(t, rec, elapsed)
			})
		}
	}
}

func TestEmailEndpointsAnswerOnTimeWhenGoTrueIsSlow(t *testing.T) {
	finished := make(chan error, 1)
	srv, _ := fakeGoTrue(t, func(w http.ResponseWriter, r *http.Request) {
		time.Sleep(3 * testEmailDelay)
		// L'envoi de l'e-mail continue : le départ du client ne l'annule pas.
		finished <- r.Context().Err()
		reply(200, `{}`)(w, r)
	})
	g := newGate(t, srv.URL)

	rec, elapsed := call(g, http.MethodPost, "/auth/v1/recover", `{"email":"a@b.c"}`)

	expectMasked(t, rec, elapsed)
	if elapsed > 2*testEmailDelay {
		t.Errorf("answered after %v, waited for the slow upstream", elapsed)
	}
	select {
	case err := <-finished:
		if err != nil {
			t.Errorf("upstream request was cancelled: %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("upstream request never finished")
	}
	g.Wait()
}

func TestEmailEndpointsCapRequestsStillInFlight(t *testing.T) {
	// Une rafale ne doit pas empiler sans fin les requêtes vers GoTrue qui
	// survivent à la réponse : au-delà du plafond, la réponse reste la même,
	// mais rien n'est relayé.
	release := make(chan struct{})
	srv, calls := fakeGoTrue(t, func(w http.ResponseWriter, r *http.Request) {
		<-release
		reply(200, `{}`)(w, r)
	})
	g, err := New(Options{
		Upstream:    srv.URL,
		EmailDelay:  testEmailDelay,
		MaxInFlight: 1,
		Logger:      slog.New(slog.NewTextHandler(io.Discard, nil)),
	})
	if err != nil {
		t.Fatalf("New: %v", err)
	}

	first, firstElapsed := call(g, http.MethodPost, "/auth/v1/recover", `{"email":"a@b.c"}`)
	next(t, calls)
	second, secondElapsed := call(g, http.MethodPost, "/auth/v1/recover", `{"email":"d@e.f"}`)
	close(release)
	g.Wait()

	expectMasked(t, first, firstElapsed)
	expectMasked(t, second, secondElapsed)
	if len(calls) != 0 {
		t.Error("request over the cap reached GoTrue")
	}
}

func TestEmailEndpointsAnswerWhenGoTrueIsDown(t *testing.T) {
	srv := httptest.NewServer(http.NotFoundHandler())
	srv.Close()

	rec, elapsed := call(newGate(t, srv.URL), http.MethodPost, "/auth/v1/signup", `{"email":"a@b.c"}`)

	expectMasked(t, rec, elapsed)
}

func TestInputErrorsPassThroughAtOnce(t *testing.T) {
	tests := []struct {
		name   string
		status int
		body   string
	}{
		{"weak_password", 422, `{"code":422,"error_code":"weak_password","msg":"Password should contain at least one character of each"}`},
		{"invalid_email", 400, `{"code":400,"error_code":"validation_failed","msg":"Unable to validate email address: invalid format"}`},
		{"captcha_failed", 400, `{"code":400,"error_code":"captcha_failed","msg":"captcha protection: request disallowed"}`},
		{"per_ip_rate_limit", 429, `{"code":429,"error_code":"over_request_rate_limit","msg":"Request rate limit reached"}`},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			srv, _ := fakeGoTrue(t, reply(tt.status, tt.body))

			rec, elapsed := call(newGate(t, srv.URL), http.MethodPost, "/auth/v1/signup", `{"email":"a@b.c"}`)

			if rec.Code != tt.status {
				t.Errorf("status = %d, want %d", rec.Code, tt.status)
			}
			if got := rec.Body.String(); got != tt.body {
				t.Errorf("body = %q, want %q", got, tt.body)
			}
			if got := rec.Header().Get("X-Supabase-Api-Version"); got != "2024-01-01" {
				t.Errorf("X-Supabase-Api-Version = %q, the client would misread the error", got)
			}
			if elapsed > immediate {
				t.Errorf("answered after %v, want at once", elapsed)
			}
		})
	}
}

func TestForwardsTheRequestToGoTrue(t *testing.T) {
	tests := []struct {
		name     string
		base     string
		wantPath string
	}{
		{"gotrue_at_the_root", "", "/recover"},
		{"gotrue_behind_a_prefix", "/auth/v1", "/auth/v1/recover"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			srv, calls := fakeGoTrue(t, reply(200, `{}`))
			body := `{"email":"a@b.c","gotrue_meta_security":{"captcha_token":"t"}}`

			call(newGate(t, srv.URL+tt.base), http.MethodPost, "/auth/v1/recover?redirect_to=https%3A%2F%2Fagora.example", body,
				"Apikey", "anon-key",
				"Authorization", "Bearer anon-key",
				"X-Forwarded-For", "203.0.113.7",
				"X-Client-Info", "supabase-dart/2",
				"Proxy-Authorization", "Basic c2VjcmV0",
				"Accept-Encoding", "br")

			got := next(t, calls)
			if got.method != http.MethodPost || got.path != tt.wantPath {
				t.Errorf("upstream got %s %s, want POST %s", got.method, got.path, tt.wantPath)
			}
			if got.query != "redirect_to=https%3A%2F%2Fagora.example" {
				t.Errorf("query = %q", got.query)
			}
			if got.body != body {
				t.Errorf("body = %q", got.body)
			}
			for _, h := range []string{"Apikey", "Authorization", "X-Client-Info", "Content-Type"} {
				if got.header.Get(h) == "" {
					t.Errorf("header %s not forwarded", h)
				}
			}
			// GoTrue limite par client d'après cet en-tête, posé par Caddy :
			// il doit arriver tel quel, sans l'adresse de la passerelle.
			if xff := got.header.Values("X-Forwarded-For"); len(xff) != 1 || xff[0] != "203.0.113.7" {
				t.Errorf("X-Forwarded-For = %q, want exactly the client address", xff)
			}
			if got.header.Get("Proxy-Authorization") != "" {
				t.Error("hop-by-hop header forwarded")
			}
			if got.header.Get("Accept-Encoding") == "br" {
				t.Error("client Accept-Encoding forwarded: the gate could not read GoTrue's error code")
			}
		})
	}
}

func TestRefusesAnOversizedBody(t *testing.T) {
	srv, calls := fakeGoTrue(t, reply(200, `{}`))

	rec, _ := call(newGate(t, srv.URL), http.MethodPost, "/auth/v1/signup", strings.Repeat("x", 70<<10))

	if rec.Code != http.StatusRequestEntityTooLarge {
		t.Errorf("status = %d, want 413", rec.Code)
	}
	if len(calls) != 0 {
		t.Error("oversized body reached GoTrue")
	}
}

func TestOnlyKnownEndpointsAndPost(t *testing.T) {
	tests := []struct {
		name, method, path string
		want               int
	}{
		{"other_auth_endpoint", http.MethodPost, "/auth/v1/factors", http.StatusNotFound},
		{"outside_auth", http.MethodPost, "/rest/v1/events", http.StatusNotFound},
		{"get_on_signup", http.MethodGet, "/auth/v1/signup", http.StatusMethodNotAllowed},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			srv, calls := fakeGoTrue(t, reply(200, `{}`))

			rec, _ := call(newGate(t, srv.URL), tt.method, tt.path, `{}`)

			if rec.Code != tt.want {
				t.Errorf("status = %d, want %d", rec.Code, tt.want)
			}
			if len(calls) != 0 {
				t.Error("request reached GoTrue")
			}
		})
	}
}

func TestSignInKeepsGoTrueAnswerButNotItsTiming(t *testing.T) {
	tests := []struct {
		name   string
		status int
		body   string
	}{
		{"unknown_address_or_wrong_password", 400, `{"code":400,"error_code":"invalid_credentials","msg":"Invalid login credentials"}`},
		{"right_password", 200, `{"access_token":"a","refresh_token":"r","user":{"id":"u1"}}`},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			srv, calls := fakeGoTrue(t, reply(tt.status, tt.body))

			rec, elapsed := call(newGate(t, srv.URL), http.MethodPost, "/auth/v1/token?grant_type=password", `{"email":"a@b.c","password":"x"}`)

			if rec.Code != tt.status || rec.Body.String() != tt.body {
				t.Errorf("got %d %q, want %d %q", rec.Code, rec.Body.String(), tt.status, tt.body)
			}
			if elapsed < testSignInFloor {
				t.Errorf("answered after %v, before the floor %v", elapsed, testSignInFloor)
			}
			if got := next(t, calls); got.path != "/token" || got.query != "grant_type=password" {
				t.Errorf("upstream got %s?%s", got.path, got.query)
			}
		})
	}
}

func TestEveryOtherGrantKeepsTheFloor(t *testing.T) {
	// GoTrue lit grant_type dans la requête ET dans un corps de formulaire :
	// seule une demande sans ambiguïté échappe au plancher.
	tests := []struct {
		name, target, contentType string
		wantFloor                 bool
	}{
		{"refresh_in_json", "/auth/v1/token?grant_type=refresh_token", "application/json", false},
		{"refresh_with_charset", "/auth/v1/token?grant_type=refresh_token", "application/json; charset=utf-8", false},
		{"refresh_claimed_over_a_form_body", "/auth/v1/token?grant_type=refresh_token", "application/x-www-form-urlencoded", true},
		{"grant_in_the_body_only", "/auth/v1/token", "application/x-www-form-urlencoded", true},
		{"pkce_exchange", "/auth/v1/token?grant_type=pkce", "application/json", true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			srv, _ := fakeGoTrue(t, reply(400, `{"code":400,"error_code":"invalid_credentials","msg":"x"}`))

			_, elapsed := call(newGate(t, srv.URL), http.MethodPost, tt.target, `grant_type=password&email=a%40b.c&password=x`,
				"Content-Type", tt.contentType)

			if tt.wantFloor && elapsed < testSignInFloor {
				t.Errorf("answered after %v, before the floor", elapsed)
			}
			if !tt.wantFloor && elapsed > immediate {
				t.Errorf("answered after %v, a session refresh should not wait", elapsed)
			}
		})
	}
}

func TestSignInWhenGoTrueIsDown(t *testing.T) {
	srv := httptest.NewServer(http.NotFoundHandler())
	srv.Close()

	rec, elapsed := call(newGate(t, srv.URL), http.MethodPost, "/auth/v1/token?grant_type=password", `{}`)

	if rec.Code != http.StatusBadGateway {
		t.Errorf("status = %d, want 502", rec.Code)
	}
	if elapsed < testSignInFloor {
		t.Errorf("answered after %v, before the floor", elapsed)
	}
}

func TestUserUpdateRefusesAnyEmailChange(t *testing.T) {
	// GoTrue répond email_exists si l'adresse visée a un compte : un compte
	// connecté sonderait ainsi toutes les adresses. L'app ne change jamais
	// d'adresse ; la passerelle refuse donc toute demande qui en porte une.
	const refused = `{"code":422,"error_code":"email_change_disabled","msg":"Email changes are disabled"}`
	bodies := []struct{ name, body string }{
		{"plain", `{"email":"autre@b.c"}`},
		{"other_case", `{"EMAIL":"autre@b.c"}`},
		{"escaped_key", `{"email":"autre@b.c"}`},
		{"with_a_password", `{"password":"Nouveau42","email":"autre@b.c"}`},
		{"trailing_data", `{"email":"autre@b.c"} {}`},
		{"not_json", `email=autre@b.c`},
	}
	for _, tt := range bodies {
		t.Run(tt.name, func(t *testing.T) {
			srv, calls := fakeGoTrue(t, reply(200, `{"id":"u1"}`))

			rec, _ := call(newGate(t, srv.URL), http.MethodPut, "/auth/v1/user", tt.body,
				"Authorization", "Bearer session")

			if rec.Code != http.StatusUnprocessableEntity || rec.Body.String() != refused {
				t.Errorf("got %d %q, want 422 %q", rec.Code, rec.Body.String(), refused)
			}
			if got := rec.Header().Get("X-Supabase-Api-Version"); got != "2024-01-01" {
				t.Errorf("X-Supabase-Api-Version = %q", got)
			}
			if len(calls) != 0 {
				t.Error("email change reached GoTrue")
			}
		})
	}
}

func TestUserUpdatePassesEverythingElseThrough(t *testing.T) {
	tests := []struct{ name, body string }{
		{"new_password", `{"password":"Nouveau42"}`},
		{"password_with_reauthentication_code", `{"password":"Nouveau42","nonce":"123456"}`},
		{"metadata_may_mention_an_email", `{"data":{"email":"pas-une-adresse-de-compte"}}`},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			srv, calls := fakeGoTrue(t, reply(200, `{"id":"u1","email":"a@b.c"}`))

			rec, elapsed := call(newGate(t, srv.URL), http.MethodPut, "/auth/v1/user", tt.body,
				"Authorization", "Bearer session")

			if rec.Code != http.StatusOK || rec.Body.String() != `{"id":"u1","email":"a@b.c"}` {
				t.Errorf("got %d %q", rec.Code, rec.Body.String())
			}
			if elapsed > immediate {
				t.Errorf("answered after %v, want at once", elapsed)
			}
			got := next(t, calls)
			if got.method != http.MethodPut || got.path != "/user" || got.body != tt.body {
				t.Errorf("upstream got %s %s %q", got.method, got.path, got.body)
			}
			if got.header.Get("Authorization") != "Bearer session" {
				t.Error("session not forwarded")
			}
		})
	}
}

func TestEachEndpointKeepsItsMethod(t *testing.T) {
	tests := []struct{ method, path string }{
		{http.MethodPost, "/auth/v1/user"},
		{http.MethodPut, "/auth/v1/signup"},
		{http.MethodPut, "/auth/v1/token"},
	}
	for _, tt := range tests {
		t.Run(tt.method+tt.path, func(t *testing.T) {
			srv, calls := fakeGoTrue(t, reply(200, `{}`))

			rec, _ := call(newGate(t, srv.URL), tt.method, tt.path, `{}`)

			if rec.Code != http.StatusMethodNotAllowed {
				t.Errorf("status = %d, want 405", rec.Code)
			}
			if len(calls) != 0 {
				t.Error("request reached GoTrue")
			}
		})
	}
}

func TestNewRejectsAnUnusableUpstream(t *testing.T) {
	for _, upstream := range []string{"", "auth:9999", "ftp://auth:9999", "http://"} {
		t.Run(upstream, func(t *testing.T) {
			if _, err := New(Options{Upstream: upstream}); err == nil {
				t.Errorf("New(%q) accepted", upstream)
			}
		})
	}
}
