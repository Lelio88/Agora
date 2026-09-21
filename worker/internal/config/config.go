// Package config lit la configuration du worker depuis l'environnement.
//
// Choix non évident : Load reçoit la fonction de lecture (os.Getenv en
// production), pour que les tests fournissent un environnement sans toucher
// aux variables du processus.
//
// Invariant : une configuration invalide fait échouer le démarrage. Le worker
// ne démarre jamais sur une valeur devinée.
//
//	cfg, err := config.Load(os.Getenv)
package config

import (
	"fmt"
	"net"
)

// Config regroupe les réglages du worker.
type Config struct {
	// HTTPAddr est l'adresse d'écoute (/healthz, puis les interactions Discord).
	HTTPAddr string
}

const defaultHTTPAddr = ":8080"

// Load construit la configuration à partir de getenv.
func Load(getenv func(string) string) (Config, error) {
	addr := getenv("AGORA_HTTP_ADDR")
	if addr == "" {
		addr = defaultHTTPAddr
	}
	if _, _, err := net.SplitHostPort(addr); err != nil {
		return Config{}, fmt.Errorf("AGORA_HTTP_ADDR %q: %w", addr, err)
	}
	return Config{HTTPAddr: addr}, nil
}
