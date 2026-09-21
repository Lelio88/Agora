// Package httpx assemble les routes HTTP du worker.
//
// Aujourd'hui /healthz seulement, sondé par Docker et Caddy. Le point
// d'entrée des interactions Discord (commandes /agenda, /dispo) s'y ajoutera :
// Discord appelle alors le worker en HTTP, sans connexion permanente à sa
// passerelle.
package httpx

import "net/http"

// NewRouter renvoie le routeur complet du worker.
func NewRouter() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		_, _ = w.Write([]byte("ok"))
	})
	return mux
}
