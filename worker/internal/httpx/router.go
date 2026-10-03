// Package httpx assemble les routes HTTP du worker.
//
// /healthz, sondé par le déploiement ; le point d'entrée des interactions
// Discord : Discord appelle le worker en HTTP, sans connexion permanente à sa
// passerelle. Sans clé publique d'application Discord, cette route n'existe
// pas — un appel non signé n'a alors rien à atteindre. Puis les routes de
// GoTrue que Caddy confie au worker, montées seulement si l'adresse de
// GoTrue est configurée : celles de la passerelle d'auth (authgate.Routes)
// et celles de la garde des jetons d'assistant (authgate.GuardRoutes). Enfin
// le serveur MCP des assistants IA et la description de sa ressource.
package httpx

import (
	"net/http"

	"github.com/Lelio88/agora/worker/assistant"
	"github.com/Lelio88/agora/worker/authgate"
)

// Handlers sont les briques montées ; une brique nulle n'est pas montée.
type Handlers struct {
	// Discord reçoit les interactions signées du bot.
	Discord http.Handler
	// AuthGate est la passerelle d'auth (inscription, mot de passe oublié,
	// renvoi de code, /token).
	AuthGate http.Handler
	// AuthGuard est la garde des routes de compte : elle refuse les jetons
	// d'assistant, puis relaie (PUT /user passe ensuite par la passerelle).
	AuthGuard http.Handler
	// MCP et ResourceMetadata sont le serveur des assistants IA.
	MCP              http.Handler
	ResourceMetadata http.Handler
}

// NewRouter renvoie le routeur complet du worker.
func NewRouter(h Handlers) http.Handler {
	mux := http.NewServeMux()
	if h.Discord != nil {
		mux.Handle("POST /discord/interactions", h.Discord)
	}
	if h.AuthGate != nil {
		for _, route := range authgate.Routes {
			mux.Handle(route, h.AuthGate)
		}
	}
	if h.AuthGuard != nil {
		for _, route := range authgate.GuardRoutes {
			mux.Handle(route, h.AuthGuard)
		}
	}
	if h.MCP != nil {
		mux.Handle(assistant.ResourcePath, h.MCP)
	}
	if h.ResourceMetadata != nil {
		mux.Handle(assistant.MetadataPath, h.ResourceMetadata)
	}
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		_, _ = w.Write([]byte("ok"))
	})
	return mux
}
