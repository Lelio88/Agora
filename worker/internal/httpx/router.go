// Package httpx assemble les routes HTTP du worker.
//
// /healthz, sondé par le déploiement, et le point d'entrée des interactions
// Discord : Discord appelle le worker en HTTP, sans connexion permanente à sa
// passerelle. Sans clé publique d'application Discord, cette route n'existe
// pas — un appel non signé n'a alors rien à atteindre.
package httpx

import "net/http"

// NewRouter renvoie le routeur complet du worker. discord est nul tant que
// le bot n'est pas branché.
func NewRouter(discord http.Handler) http.Handler {
	mux := http.NewServeMux()
	if discord != nil {
		mux.Handle("POST /discord/interactions", discord)
	}
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		_, _ = w.Write([]byte("ok"))
	})
	return mux
}
