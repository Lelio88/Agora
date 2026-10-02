// Package httpx assemble les routes HTTP du worker.
//
// /healthz, sondé par le déploiement ; le point d'entrée des interactions
// Discord : Discord appelle le worker en HTTP, sans connexion permanente à sa
// passerelle. Sans clé publique d'application Discord, cette route n'existe
// pas — un appel non signé n'a alors rien à atteindre. Enfin, les routes de
// GoTrue que Caddy confie à la passerelle d'auth (authgate.Routes), montées
// seulement si l'adresse de GoTrue est configurée.
package httpx

import (
	"net/http"

	"github.com/Lelio88/agora/worker/authgate"
)

// NewRouter renvoie le routeur complet du worker. discord est nul tant que
// le bot n'est pas branché, auth tant que la passerelle d'auth ne l'est pas.
func NewRouter(discord, auth http.Handler) http.Handler {
	mux := http.NewServeMux()
	if discord != nil {
		mux.Handle("POST /discord/interactions", discord)
	}
	if auth != nil {
		for _, route := range authgate.Routes {
			mux.Handle(route, auth)
		}
	}
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		_, _ = w.Write([]byte("ok"))
	})
	return mux
}
