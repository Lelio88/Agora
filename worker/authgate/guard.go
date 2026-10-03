package authgate

import (
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"

	"github.com/Lelio88/agora/worker/internal/bearer"
)

// Guard est la garde des routes de compte de GoTrue : elle refuse tout jeton
// d'assistant IA (claim client_id) et relaie le reste tel quel.
//
// Un assistant reçoit de GoTrue un jeton d'utilisateur presque complet : sur
// ces routes, il pourrait changer le mot de passe (aucune réidentification
// pour une session neuve), lier ou délier une identité, fermer toutes les
// sessions du compte, lire l'adresse e-mail ou accorder un autre accès OAuth
// au nom du membre. Aucun réglage de GoTrue ne l'empêche, la base non plus :
// la garde le fait ici, devant GoTrue. Le jeton d'un assistant ne vaut que
// pour /mcp (paquet assistant) ; PostgREST et le temps réel le refusent en
// base (migration 20261003120000_assistant.sql).
//
// Choix non évidents :
//   - liste d'admission : Caddy lui envoie toute requête à GoTrue qui porte un
//     en-tête Authorization (sauf l'échange de jetons OAuth et l'inscription
//     des clients) ; un jeton d'assistant n'atteint donc aucune route de
//     GoTrue, connue ou à venir ;
//   - la garde passe AUSSI devant PUT /user : elle ne confie la mise à jour du
//     compte à la passerelle (refus du changement d'adresse) qu'après son
//     propre contrôle. C'est pourquoi Routes ne contient plus PUT /user — un
//     motif ServeMux avec méthode, plus précis, contournerait la garde ;
//   - le jeton est lu sans vérifier sa signature (paquet bearer) : on ne fait
//     que refuser davantage, GoTrue juge le reste ;
//   - X-Forwarded-For, posé par Caddy, est relayé tel quel (GoTrue limite par
//     client d'après lui), comme par la passerelle.
//
// Invariant : rien du jeton ni du corps n'est journalisé.
type Guard struct {
	proxy      *httputil.ReverseProxy
	userUpdate http.Handler
}

// GuardRoutes sont les motifs ServeMux (toutes méthodes) de la garde. Caddy
// lui envoie les routes de compte (le compte, ses identités et accès
// accordés, la déconnexion, les facteurs, la réidentification, le
// consentement OAuth), et **toute autre route de GoTrue qui reçoit un en-tête
// Authorization** : c'est une liste d'admission — une route qu'une version
// future de GoTrue ajouterait est gardée d'office. Les routes de la
// passerelle (Routes), plus précises, passent avant.
var GuardRoutes = []string{prefix + "/"}

// gateEndpoints sont les points d'entrée de la passerelle : une variante
// d'écriture (casse, barre finale) n'atteint jamais GoTrue en direct.
var gateEndpoints = []string{"/signup", "/recover", "/resend", "/token"}

// assistantForbidden répond à un jeton d'assistant, au format de GoTrue.
const assistantForbidden = `{"code":403,"error_code":"assistant_forbidden","msg":"Assistant tokens are only valid for /mcp"}`

// NewGuard construit la garde devant upstream (GoTrue) ; userUpdate traite
// PUT /user une fois le contrôle passé (la passerelle).
func NewGuard(upstream string, userUpdate http.Handler, logger *slog.Logger) (*Guard, error) {
	target, err := url.Parse(upstream)
	if err != nil || (target.Scheme != "http" && target.Scheme != "https") || target.Host == "" {
		return nil, fmt.Errorf("authgate: upstream %q: http(s) URL with a host expected", upstream)
	}
	if logger == nil {
		logger = slog.Default()
	}
	base := strings.TrimRight(target.Path, "/")
	proxy := &httputil.ReverseProxy{
		Rewrite: func(pr *httputil.ProxyRequest) {
			pr.Out.URL.Scheme = target.Scheme
			pr.Out.URL.Host = target.Host
			pr.Out.URL.Path = base + strings.TrimPrefix(pr.In.URL.Path, prefix)
			pr.Out.URL.RawPath = ""
			pr.Out.Host = target.Host
			if xff := pr.In.Header.Values("X-Forwarded-For"); len(xff) > 0 {
				pr.Out.Header["X-Forwarded-For"] = xff
			}
		},
		ErrorHandler: func(w http.ResponseWriter, r *http.Request, err error) {
			logger.Warn("auth guard: gotrue unreachable", "path", r.URL.Path, "err", err)
			writeJSON(w, http.StatusBadGateway, unavailable)
		},
	}
	return &Guard{proxy: proxy, userUpdate: userUpdate}, nil
}

// ServeHTTP refuse un jeton d'assistant, puis relaie.
func (g *Guard) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if isGateVariant(r.URL.Path) {
		http.NotFound(w, r)
		return
	}
	if c, err := bearer.Read(bearer.FromHeader(r.Header.Get("Authorization"))); err == nil && c.ClientID != "" {
		writeJSON(w, http.StatusForbidden, assistantForbidden)
		return
	}
	if r.Method == http.MethodPut && r.URL.Path == prefix+"/user" {
		g.userUpdate.ServeHTTP(w, r)
		return
	}
	g.proxy.ServeHTTP(w, r)
}

// isGateVariant dit si path ressemble à un point d'entrée de la passerelle
// sans en être un : ces routes-là se jouent à la passerelle ou nulle part.
func isGateVariant(path string) bool {
	rest := strings.ToLower(strings.TrimPrefix(path, prefix))
	for _, endpoint := range gateEndpoints {
		if strings.HasPrefix(rest, endpoint) {
			return true
		}
	}
	return false
}
