package ics

import (
	"context"
	"crypto/tls"
	"errors"
	"io"
	"net"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const (
	// fetchTimeout borne une relecture entière, corps compris.
	fetchTimeout = 20 * time.Second
	dialTimeout  = 10 * time.Second
	// maxBodyBytes borne le flux, décompressé.
	maxBodyBytes = 5 << 20
	maxRedirects = 3
	// Un validateur plus long n'est pas conservé (la base le stocke).
	maxValidatorLength = 512
	userAgent          = "Agora-Calendar/1.0 (+https://github.com/Lelio88/Agora)"
)

var (
	errTooManyRedirects = errors.New("ics: too many redirects")
	errInsecureRedirect = errors.New("ics: redirect to a non-https address")
)

// Result est la réponse d'une relecture.
type Result struct {
	// NotModified : le flux n'a pas changé depuis ETag / LastModified.
	NotModified  bool
	Body         []byte
	ETag         string
	LastModified string
}

// HTTPFetcher télécharge les flux, en https seulement.
type HTTPFetcher struct {
	client  *http.Client
	timeout time.Duration
}

// NewHTTPFetcher construit le client. allowPrivateNetwork lève le contrôle
// SSRF : développement et tests seulement.
func NewHTTPFetcher(allowPrivateNetwork bool) *HTTPFetcher {
	return newHTTPFetcher(allowPrivateNetwork, nil)
}

// newHTTPFetcher accepte une configuration TLS (tests : certificat d'un
// serveur httptest).
func newHTTPFetcher(allowPrivateNetwork bool, tlsConfig *tls.Config) *HTTPFetcher {
	dialer := &net.Dialer{Timeout: dialTimeout, Control: guardDial(allowPrivateNetwork)}
	transport := &http.Transport{
		// Pas de mandataire : le contrôle porterait sur lui, pas sur la cible.
		Proxy:                  nil,
		DialContext:            dialer.DialContext,
		TLSClientConfig:        tlsConfig,
		TLSHandshakeTimeout:    dialTimeout,
		MaxResponseHeaderBytes: 64 << 10,
		MaxIdleConns:           4,
		IdleConnTimeout:        30 * time.Second,
		ForceAttemptHTTP2:      true,
	}
	client := &http.Client{
		Transport: transport,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) > maxRedirects {
				return errTooManyRedirects
			}
			if req.URL.Scheme != "https" {
				return errInsecureRedirect
			}
			return nil
		},
	}
	return &HTTPFetcher{client: client, timeout: fetchTimeout}
}

// Fetch relit un flux, en conditionnel si ETag ou LastModified sont connus.
// L'erreur est une Failure, ou l'erreur de ctx à l'arrêt du worker — jamais
// une erreur qui citerait l'URL.
func (f *HTTPFetcher) Fetch(ctx context.Context, feed Feed) (Result, error) {
	target, err := url.Parse(feed.URL)
	if err != nil || target.Scheme != "https" || target.Host == "" {
		return Result{}, FailureHTTP
	}
	requestCtx, cancel := context.WithTimeout(ctx, f.timeout)
	defer cancel()
	req, err := http.NewRequestWithContext(requestCtx, http.MethodGet, target.String(), nil)
	if err != nil {
		return Result{}, FailureHTTP
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "text/calendar, text/plain;q=0.5, */*;q=0.1")
	if feed.ETag != "" {
		req.Header.Set("If-None-Match", feed.ETag)
	}
	if feed.LastModified != "" {
		req.Header.Set("If-Modified-Since", feed.LastModified)
	}
	resp, err := f.client.Do(req)
	if err != nil {
		return Result{}, classify(ctx, err)
	}
	defer resp.Body.Close()

	switch {
	case resp.StatusCode == http.StatusNotModified:
		return Result{NotModified: true}, nil
	case resp.StatusCode == http.StatusNotFound || resp.StatusCode == http.StatusGone:
		return Result{}, FailureNotFound
	case resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusForbidden:
		return Result{}, FailureForbidden
	case resp.StatusCode != http.StatusOK:
		return Result{}, FailureHTTP
	case resp.ContentLength > maxBodyBytes:
		return Result{}, FailureTooLarge
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxBodyBytes+1))
	if err != nil {
		return Result{}, classify(ctx, err)
	}
	if len(body) > maxBodyBytes {
		return Result{}, FailureTooLarge
	}
	return Result{
		Body:         body,
		ETag:         validator(resp.Header.Get("ETag")),
		LastModified: validator(resp.Header.Get("Last-Modified")),
	}, nil
}

// classify réduit une erreur réseau à son code. L'arrêt du worker (ctx
// annulé) n'est pas un échec du flux : son erreur remonte telle quelle.
func classify(ctx context.Context, err error) error {
	if ctx.Err() != nil {
		return ctx.Err()
	}
	var netErr net.Error
	switch {
	case errors.Is(err, errBlockedAddress):
		return FailureBlockedAddress
	case errors.Is(err, errTooManyRedirects), errors.Is(err, errInsecureRedirect):
		return FailureHTTP
	case errors.Is(err, context.DeadlineExceeded), errors.As(err, &netErr) && netErr.Timeout():
		return FailureTimeout
	default:
		return FailureUnreachable
	}
}

func validator(value string) string {
	value = strings.TrimSpace(value)
	if len(value) > maxValidatorLength {
		return ""
	}
	return value
}
