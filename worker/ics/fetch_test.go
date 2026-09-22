package ics

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// secretPath figure dans chaque URL de test : aucune erreur ne doit le
// contenir.
const secretPath = "/private-7f3a9c/basic.ics"

// newTestServer sert handler en TLS ; le client renvoyé fait confiance à
// son certificat et lève le contrôle SSRF (le serveur est en 127.0.0.1).
func newTestServer(t *testing.T, handler http.HandlerFunc) (*httptest.Server, *HTTPFetcher) {
	t.Helper()
	server := httptest.NewTLSServer(handler)
	t.Cleanup(server.Close)
	roots := x509.NewCertPool()
	roots.AddCert(server.Certificate())
	return server, newHTTPFetcher(true, &tls.Config{RootCAs: roots})
}

func TestFetchReadsTheFeedAndItsValidators(t *testing.T) {
	var gotHeaders http.Header
	server, fetcher := newTestServer(t, func(w http.ResponseWriter, r *http.Request) {
		gotHeaders = r.Header.Clone()
		w.Header().Set("ETag", `"v2"`)
		w.Header().Set("Last-Modified", "Tue, 22 Sep 2026 10:00:00 GMT")
		_, _ = w.Write([]byte("BEGIN:VCALENDAR"))
	})

	result, err := fetcher.Fetch(context.Background(), Feed{URL: server.URL + secretPath, ETag: `"v1"`})
	if err != nil {
		t.Fatalf("Fetch() error = %v", err)
	}
	if string(result.Body) != "BEGIN:VCALENDAR" || result.ETag != `"v2"` || result.LastModified == "" {
		t.Errorf("result = %+v", result)
	}
	if gotHeaders.Get("If-None-Match") != `"v1"` || !strings.HasPrefix(gotHeaders.Get("User-Agent"), "Agora") {
		t.Errorf("request headers = %v", gotHeaders)
	}
}

func TestFetchNotModified(t *testing.T) {
	server, fetcher := newTestServer(t, func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNotModified)
	})
	result, err := fetcher.Fetch(context.Background(), Feed{URL: server.URL + secretPath, ETag: `"v1"`})
	if err != nil || !result.NotModified {
		t.Errorf("Fetch() = %+v, %v, want not modified", result, err)
	}
}

func TestFetchFailures(t *testing.T) {
	big := strings.Repeat("x", maxBodyBytes+1)
	tests := []struct {
		name    string
		handler http.HandlerFunc
		want    Failure
	}{
		{name: "not found", handler: status(http.StatusNotFound), want: FailureNotFound},
		{name: "gone", handler: status(http.StatusGone), want: FailureNotFound},
		{name: "forbidden", handler: status(http.StatusForbidden), want: FailureForbidden},
		{name: "unauthorized", handler: status(http.StatusUnauthorized), want: FailureForbidden},
		{name: "server error", handler: status(http.StatusBadGateway), want: FailureHTTP},
		{name: "declared too large", handler: func(w http.ResponseWriter, _ *http.Request) {
			_, _ = w.Write([]byte(big))
		}, want: FailureTooLarge},
		{name: "streamed too large", handler: func(w http.ResponseWriter, _ *http.Request) {
			w.(http.Flusher).Flush() // sans Content-Length
			_, _ = w.Write([]byte(big))
		}, want: FailureTooLarge},
		{name: "redirect to http", handler: func(w http.ResponseWriter, r *http.Request) {
			http.Redirect(w, r, "http://example.com/feed.ics", http.StatusFound)
		}, want: FailureHTTP},
		{name: "endless redirects", handler: func(w http.ResponseWriter, r *http.Request) {
			http.Redirect(w, r, r.URL.Path+"x", http.StatusFound)
		}, want: FailureHTTP},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			server, fetcher := newTestServer(t, tt.handler)
			_, err := fetcher.Fetch(context.Background(), Feed{URL: server.URL + secretPath})
			assertFailure(t, err, tt.want)
		})
	}
}

func TestFetchTimeout(t *testing.T) {
	release := make(chan struct{})
	server, fetcher := newTestServer(t, func(w http.ResponseWriter, _ *http.Request) {
		<-release
	})
	defer close(release)
	fetcher.timeout = 50 * time.Millisecond

	_, err := fetcher.Fetch(context.Background(), Feed{URL: server.URL + secretPath})
	assertFailure(t, err, FailureTimeout)
}

func TestFetchBlocksPrivateAddresses(t *testing.T) {
	server, _ := newTestServer(t, status(http.StatusOK))
	fetcher := NewHTTPFetcher(false)

	_, err := fetcher.Fetch(context.Background(), Feed{URL: server.URL + secretPath})
	assertFailure(t, err, FailureBlockedAddress)
}

func TestFetchRefusesPlainHTTP(t *testing.T) {
	_, err := NewHTTPFetcher(true).Fetch(context.Background(), Feed{URL: "http://127.0.0.1" + secretPath})
	assertFailure(t, err, FailureHTTP)
}

func TestFetchReturnsTheContextErrorOnShutdown(t *testing.T) {
	server, fetcher := newTestServer(t, status(http.StatusOK))
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	_, err := fetcher.Fetch(ctx, Feed{URL: server.URL + secretPath})
	if !errors.Is(err, context.Canceled) {
		t.Errorf("Fetch() error = %v, want context.Canceled (not a feed failure)", err)
	}
}

func status(code int) http.HandlerFunc {
	return func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(code) }
}

func assertFailure(t *testing.T, err error, want Failure) {
	t.Helper()
	if !errors.Is(err, want) {
		t.Errorf("error = %v, want %v", err, want)
	}
	if err != nil && strings.Contains(err.Error(), secretPath) {
		t.Errorf("the error reveals the feed URL: %v", err)
	}
}
