// Package config lit la configuration du worker depuis l'environnement.
//
// Choix non évident : Load reçoit la fonction de lecture (os.Getenv en
// production), pour que les tests fournissent un environnement sans toucher
// aux variables du processus.
//
// Invariants :
//
//   - une configuration invalide fait échouer le démarrage ; le worker ne
//     démarre jamais sur une valeur devinée ;
//
//   - le mot de passe de la base ne sort jamais d'ici en clair : les journaux
//     utilisent RedactedDatabaseURL.
//
//     cfg, err := config.Load(os.Getenv)
package config

import (
	"errors"
	"fmt"
	"net"
	"net/url"
	"strconv"
)

// Config regroupe les réglages du worker.
type Config struct {
	// HTTPAddr est l'adresse d'écoute (/healthz, puis les interactions Discord).
	HTTPAddr string
	// DatabaseURL est la connexion Postgres, sous le rôle agora_worker.
	DatabaseURL string
	// ICSAllowPrivateNetwork lève le contrôle SSRF des flux iCal
	// (AGORA_ICS_ALLOW_PRIVATE_NETWORK=true) : développement et tests
	// seulement, jamais en production.
	ICSAllowPrivateNetwork bool
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
	databaseURL := getenv("AGORA_DATABASE_URL")
	if databaseURL == "" {
		return Config{}, errors.New("AGORA_DATABASE_URL is required")
	}
	parsed, err := url.Parse(databaseURL)
	if err != nil || (parsed.Scheme != "postgres" && parsed.Scheme != "postgresql") {
		return Config{}, errors.New("AGORA_DATABASE_URL must be a postgres:// URL")
	}
	allowPrivate := false
	if raw := getenv("AGORA_ICS_ALLOW_PRIVATE_NETWORK"); raw != "" {
		allowPrivate, err = strconv.ParseBool(raw)
		if err != nil {
			return Config{}, fmt.Errorf("AGORA_ICS_ALLOW_PRIVATE_NETWORK %q: not a boolean", raw)
		}
	}
	return Config{HTTPAddr: addr, DatabaseURL: databaseURL, ICSAllowPrivateNetwork: allowPrivate}, nil
}

// RedactedDatabaseURL renvoie DatabaseURL sans son mot de passe, pour les
// journaux.
func (c Config) RedactedDatabaseURL() string {
	parsed, err := url.Parse(c.DatabaseURL)
	if err != nil {
		return "(invalid)"
	}
	return parsed.Redacted()
}
