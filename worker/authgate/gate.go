// Package authgate est la passerelle d'Agora devant les points d'entrée de
// GoTrue qui laisseraient deviner si une adresse a un compte.
//
// GoTrue répond différemment selon l'état d'une adresse : une inscription
// renvoie l'utilisateur créé ou un utilisateur factice sans identité, deux
// demandes en moins d'une minute donnent 429 pour un compte et 200 pour une
// adresse inconnue, et la durée trahit l'envoi d'un e-mail ou la vérification
// d'un mot de passe. Caddy envoie donc ici les requêtes concernées ; la
// passerelle les relaie à GoTrue et :
//
//   - pour l'inscription, le mot de passe oublié et le renvoi de code, répond
//     toujours 200 « {} », et toujours au bout du même délai (EmailDelay),
//     que GoTrue ait réussi, limité, échoué ou pas encore répondu ;
//   - pour /token, rend la réponse de GoTrue telle quelle, jamais avant un
//     plancher (SignInFloor) qui couvre la vérification du mot de passe ;
//   - pour PUT /user, refuse tout changement d'adresse (GoTrue répondrait
//     email_exists si l'adresse visée a un compte) et relaie le reste tel
//     quel : l'app ne change que le mot de passe.
//
// Choix non évidents :
//
//   - seules les erreurs qui ne dépendent que de la saisie passent tout de
//     suite (mot de passe faible, adresse mal formée, captcha refusé, limite
//     par adresse IP) : GoTrue les rend avant de chercher le compte. Un 429
//     inconnu est masqué : on ne laisse passer que ce qu'on sait sans
//     danger ;
//   - au-delà du délai, la réponse part sans attendre GoTrue, dont la
//     requête continue sous un contexte détaché : le titulaire reçoit son
//     e-mail même si l'envoi SMTP est lent. Ces requêtes sont plafonnées
//     (MaxInFlight) : au-delà, la réponse reste la même mais rien n'est
//     relayé, pour qu'une rafale n'empile pas sans fin connexions et
//     goroutines ;
//   - GoTrue lit grant_type dans la requête et dans un corps de formulaire :
//     seul un rafraîchissement de session en JSON échappe au plancher ;
//   - une demande de PUT /user illisible est refusée : GoTrue lit le JSON
//     avec plus d'indulgence (clés sans casse, données en trop) que ce qu'on
//     saurait vérifier ;
//   - l'Accept-Encoding du client n'est pas relayé, pour que la passerelle
//     lise toujours en clair le code d'erreur de GoTrue ; X-Forwarded-For,
//     posé par Caddy, l'est tel quel : GoTrue limite par client d'après lui.
//
// Invariants : aucun corps (adresse, mot de passe, jeton) n'est journalisé ;
// la passerelle ne garde rien entre deux requêtes.
//
//	gate, err := authgate.New(authgate.Options{Upstream: "http://auth:9999"})
//	for _, route := range authgate.Routes {
//		mux.Handle(route, gate)
//	}
package authgate

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"mime"
	"net/http"
	"net/url"
	"slices"
	"strings"
	"sync"
	"time"
)

const (
	// DefaultEmailDelay laisse le temps d'un envoi SMTP ordinaire ; au-delà,
	// la réponse part quand même.
	DefaultEmailDelay = 1500 * time.Millisecond
	// DefaultSignInFloor couvre la vérification bcrypt d'un mot de passe et
	// celle du captcha, que GoTrue ne fait que pour un compte existant.
	DefaultSignInFloor = 800 * time.Millisecond

	maxRequestBody  = 64 << 10
	maxResponseBody = 1 << 20
	// upstreamTimeout borne une requête relayée, y compris celle qui
	// continue après la réponse au client.
	upstreamTimeout = 30 * time.Second
	// DefaultMaxInFlight plafonne les requêtes d'e-mail en route vers
	// GoTrue : bien au-delà de l'usage réel, bien en deçà de ce qui
	// épuiserait le worker (96 Mo).
	DefaultMaxInFlight = 64
	// apiVersion est l'en-tête que GoTrue joint à ses réponses ; le client
	// Supabase s'en sert pour lire les erreurs.
	apiVersion           = "2024-01-01"
	errorCodeIPRateLimit = "over_request_rate_limit"
	prefix               = "/auth/v1"
	// unavailable répond quand GoTrue ne répond pas.
	unavailable = `{"code":502,"error_code":"unexpected_failure","msg":"Authentication service unavailable"}`
)

// methods donne, pour chaque point d'entrée relayé, sa seule méthode.
var methods = map[string]string{
	"/signup":  http.MethodPost,
	"/recover": http.MethodPost,
	"/resend":  http.MethodPost,
	"/token":   http.MethodPost,
	"/user":    http.MethodPut,
}

// Routes sont les routes que Caddy envoie à la passerelle, au format des
// motifs de http.ServeMux.
var Routes = []string{
	"POST " + prefix + "/signup",
	"POST " + prefix + "/recover",
	"POST " + prefix + "/resend",
	"POST " + prefix + "/token",
	"PUT " + prefix + "/user",
}

// emailChangeRefused répond à toute demande de changement d'adresse.
const emailChangeRefused = `{"code":422,"error_code":"email_change_disabled","msg":"Email changes are disabled"}`

// hopByHop ne concernent qu'un tronçon de connexion : jamais relayés.
var hopByHop = []string{
	"Connection", "Proxy-Connection", "Keep-Alive", "Proxy-Authenticate",
	"Proxy-Authorization", "Te", "Trailer", "Transfer-Encoding", "Upgrade",
}

// Options règle la passerelle.
type Options struct {
	// Upstream est l'adresse de GoTrue, préfixe compris s'il en a un
	// (« http://auth:9999 » en production).
	Upstream string
	// Client relaie les requêtes ; par défaut, un client sans délai propre
	// (chaque requête porte le sien).
	Client *http.Client
	// EmailDelay et SignInFloor : DefaultEmailDelay et DefaultSignInFloor
	// si nuls.
	EmailDelay  time.Duration
	SignInFloor time.Duration
	// MaxInFlight : DefaultMaxInFlight si nul.
	MaxInFlight int
	Logger      *slog.Logger
}

// Gate relaie les requêtes sensibles à GoTrue. Voir le commentaire du paquet.
type Gate struct {
	upstream    *url.URL
	client      *http.Client
	emailDelay  time.Duration
	signInFloor time.Duration
	logger      *slog.Logger
	// inflight compte les requêtes encore en route vers GoTrue après la
	// réponse au client ; slots les plafonne.
	inflight sync.WaitGroup
	slots    chan struct{}
}

// answer est une réponse de GoTrue, lue en entier.
type answer struct {
	status int
	header http.Header
	body   []byte
}

// New valide les options et construit la passerelle.
func New(opts Options) (*Gate, error) {
	upstream, err := url.Parse(opts.Upstream)
	if err != nil || (upstream.Scheme != "http" && upstream.Scheme != "https") || upstream.Host == "" {
		return nil, fmt.Errorf("authgate: upstream %q: http(s) URL with a host expected", opts.Upstream)
	}
	g := &Gate{
		upstream:    upstream,
		client:      opts.Client,
		emailDelay:  opts.EmailDelay,
		signInFloor: opts.SignInFloor,
		logger:      opts.Logger,
	}
	if g.client == nil {
		g.client = &http.Client{}
	}
	if g.emailDelay <= 0 {
		g.emailDelay = DefaultEmailDelay
	}
	if g.signInFloor <= 0 {
		g.signInFloor = DefaultSignInFloor
	}
	if g.logger == nil {
		g.logger = slog.Default()
	}
	maxInFlight := opts.MaxInFlight
	if maxInFlight <= 0 {
		maxInFlight = DefaultMaxInFlight
	}
	g.slots = make(chan struct{}, maxInFlight)
	return g, nil
}

// Wait attend les requêtes encore en route vers GoTrue : à l'arrêt, un
// e-mail en cours d'envoi part quand même.
func (g *Gate) Wait() {
	g.inflight.Wait()
}

// ServeHTTP route une requête vers le traitement de son point d'entrée.
func (g *Gate) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	endpoint, ok := strings.CutPrefix(r.URL.Path, prefix)
	method, known := methods[endpoint]
	if !ok || !known {
		http.NotFound(w, r)
		return
	}
	if r.Method != method {
		w.Header().Set("Allow", method)
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxRequestBody))
	if err != nil {
		if _, tooLarge := errors.AsType[*http.MaxBytesError](err); tooLarge {
			http.Error(w, "request body too large", http.StatusRequestEntityTooLarge)
			return
		}
		http.Error(w, "unreadable request body", http.StatusBadRequest)
		return
	}
	switch endpoint {
	case "/token":
		g.serveToken(w, r, body, start)
	case "/user":
		g.serveUserUpdate(w, r, body)
	default:
		g.serveEmail(w, r, endpoint, body, start)
	}
}

// serveEmail répond au bout de emailDelay, d'une seule façon, sauf erreur
// de saisie, rendue tout de suite.
func (g *Gate) serveEmail(w http.ResponseWriter, r *http.Request, endpoint string, body []byte, start time.Time) {
	passed := make(chan answer, 1)
	select {
	case g.slots <- struct{}{}:
	default:
		g.logger.Warn("auth gate: too many requests in flight, not relayed", "endpoint", endpoint)
		wait(r.Context(), start.Add(g.emailDelay))
		writeMasked(w)
		return
	}
	ctx, cancel := context.WithTimeout(context.WithoutCancel(r.Context()), upstreamTimeout)
	g.inflight.Add(1)
	go func() {
		defer g.inflight.Done()
		defer func() { <-g.slots }()
		defer cancel()
		a, err := g.forward(ctx, r, endpoint, body)
		switch {
		case err != nil:
			g.logger.Warn("auth gate: gotrue unreachable", "endpoint", endpoint, "err", err)
		case a.status >= http.StatusInternalServerError:
			g.logger.Warn("auth gate: gotrue failed", "endpoint", endpoint, "status", a.status)
		case passesThrough(a):
			passed <- a
		}
	}()

	deadline := time.NewTimer(time.Until(start.Add(g.emailDelay)))
	defer deadline.Stop()
	select {
	case a := <-passed:
		writeAnswer(w, a)
	case <-deadline.C:
		writeMasked(w)
	case <-r.Context().Done():
	}
}

// serveToken rend la réponse de GoTrue, pas avant signInFloor sauf pour un
// rafraîchissement de session sans ambiguïté.
func (g *Gate) serveToken(w http.ResponseWriter, r *http.Request, body []byte, start time.Time) {
	ctx, cancel := context.WithTimeout(r.Context(), upstreamTimeout)
	defer cancel()
	a, err := g.forward(ctx, r, "/token", body)
	if !isPlainRefresh(r) {
		wait(r.Context(), start.Add(g.signInFloor))
	}
	if err != nil {
		g.logger.Warn("auth gate: gotrue unreachable", "endpoint", "/token", "err", err)
		writeJSON(w, http.StatusBadGateway, unavailable)
		return
	}
	writeAnswer(w, a)
}

// serveUserUpdate relaie une mise à jour du compte, sauf si elle change
// l'adresse.
func (g *Gate) serveUserUpdate(w http.ResponseWriter, r *http.Request, body []byte) {
	if !withoutEmail(body) {
		writeJSON(w, http.StatusUnprocessableEntity, emailChangeRefused)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), upstreamTimeout)
	defer cancel()
	a, err := g.forward(ctx, r, "/user", body)
	if err != nil {
		g.logger.Warn("auth gate: gotrue unreachable", "endpoint", "/user", "err", err)
		writeJSON(w, http.StatusBadGateway, unavailable)
		return
	}
	writeAnswer(w, a)
}

// withoutEmail dit si body est un objet JSON sans clé « email », quelle
// qu'en soit la casse. Illisible : faux.
func withoutEmail(body []byte) bool {
	var fields map[string]json.RawMessage
	if json.NewDecoder(bytes.NewReader(body)).Decode(&fields) != nil {
		return false
	}
	for key := range fields {
		if strings.EqualFold(key, "email") {
			return false
		}
	}
	return true
}

// forward relaie la requête à GoTrue et lit sa réponse.
func (g *Gate) forward(ctx context.Context, r *http.Request, endpoint string, body []byte) (answer, error) {
	target := g.upstream.JoinPath(endpoint)
	target.RawQuery = r.URL.RawQuery
	req, err := http.NewRequestWithContext(ctx, r.Method, target.String(), bytes.NewReader(body))
	if err != nil {
		return answer{}, fmt.Errorf("build request: %w", err)
	}
	copyHeader(req.Header, r.Header)
	req.Header.Del("Accept-Encoding")
	resp, err := g.client.Do(req)
	if err != nil {
		// L'erreur d'URL répète la requête : on n'en garde que la cause.
		if urlErr, ok := errors.AsType[*url.Error](err); ok {
			err = urlErr.Err
		}
		return answer{}, fmt.Errorf("call gotrue: %w", err)
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxResponseBody+1))
	if err != nil {
		return answer{}, fmt.Errorf("read gotrue answer: %w", err)
	}
	if len(data) > maxResponseBody {
		return answer{}, errors.New("gotrue answer too large")
	}
	return answer{status: resp.StatusCode, header: resp.Header, body: data}, nil
}

// passesThrough dit si une réponse de GoTrue peut être rendue telle quelle :
// une erreur qui ne dépend que de la saisie.
func passesThrough(a answer) bool {
	if a.status < http.StatusBadRequest || a.status >= http.StatusInternalServerError {
		return false
	}
	if a.status != http.StatusTooManyRequests {
		return true
	}
	return errorCode(a) == errorCodeIPRateLimit
}

// errorCode lit le code d'erreur de GoTrue dans le corps de sa réponse.
func errorCode(a answer) string {
	var payload struct {
		ErrorCode string `json:"error_code"`
	}
	if json.Unmarshal(a.body, &payload) != nil {
		return ""
	}
	return payload.ErrorCode
}

// isPlainRefresh dit si la requête ne peut être qu'un rafraîchissement de
// session : grant_type dans la requête, et un corps JSON, que GoTrue ne lit
// pas comme un formulaire.
func isPlainRefresh(r *http.Request) bool {
	if r.URL.Query().Get("grant_type") != "refresh_token" {
		return false
	}
	mediaType, _, err := mime.ParseMediaType(r.Header.Get("Content-Type"))
	return err == nil && mediaType == "application/json"
}

// wait attend until, ou le départ du client.
func wait(ctx context.Context, until time.Time) {
	t := time.NewTimer(time.Until(until))
	defer t.Stop()
	select {
	case <-t.C:
	case <-ctx.Done():
	}
}

// writeMasked est la réponse unique des points d'entrée qui envoient un
// e-mail : celle que GoTrue fait déjà à une adresse inconnue.
func writeMasked(w http.ResponseWriter) {
	writeJSON(w, http.StatusOK, "{}")
}

// writeJSON écrit une réponse de la passerelle, au format de celles de
// GoTrue.
func writeJSON(w http.ResponseWriter, status int, body string) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("X-Supabase-Api-Version", apiVersion)
	w.WriteHeader(status)
	_, _ = io.WriteString(w, body)
}

// writeAnswer rend une réponse de GoTrue telle quelle.
func writeAnswer(w http.ResponseWriter, a answer) {
	copyHeader(w.Header(), a.header)
	w.Header().Del("Content-Length")
	w.WriteHeader(a.status)
	_, _ = w.Write(a.body)
}

// copyHeader recopie les en-têtes de bout en bout, sans ceux d'un seul
// tronçon ni ceux que Connection désigne comme tels.
func copyHeader(dst, src http.Header) {
	skip := slices.Clone(hopByHop)
	for _, field := range src.Values("Connection") {
		for name := range strings.SplitSeq(field, ",") {
			skip = append(skip, http.CanonicalHeaderKey(strings.TrimSpace(name)))
		}
	}
	for name, values := range src {
		if slices.Contains(skip, name) {
			continue
		}
		dst[name] = slices.Clone(values)
	}
}
