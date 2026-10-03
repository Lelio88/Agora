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
	"crypto/ed25519"
	"encoding/hex"
	"errors"
	"fmt"
	"net"
	"net/url"
	"strconv"
	"strings"
)

// Config regroupe les réglages du worker.
type Config struct {
	// HTTPAddr est l'adresse d'écoute (/healthz, puis les interactions Discord).
	HTTPAddr string
	// DatabaseURL est la connexion Postgres, sous le rôle agora_worker.
	DatabaseURL string
	// DiscordPublicKey est la clé publique hexadécimale de l'application
	// Discord, qui signe chaque interaction. Vide : le bot n'est pas branché
	// et le point d'entrée des interactions n'est pas monté.
	DiscordPublicKey string
	// DiscordBotToken est le jeton du bot, qui publie récaps et rappels par
	// l'API REST. Vide : rien n'est publié. Un secret : jamais journalisé.
	DiscordBotToken string
	// DiscordApplicationID identifie l'application Discord, pour inscrire
	// les commandes (worker register-commands).
	DiscordApplicationID string
	// ICSAllowPrivateNetwork lève le contrôle SSRF des flux iCal
	// (AGORA_ICS_ALLOW_PRIVATE_NETWORK=true) : développement et tests
	// seulement, jamais en production.
	ICSAllowPrivateNetwork bool
	// AuthUpstream est l'adresse de GoTrue derrière la passerelle d'auth
	// (paquet authgate). Vide : la passerelle n'est pas montée.
	AuthUpstream string
	// PublicAPIURL est l'adresse publique de l'API (https://api.agora…) :
	// celle que voient les assistants IA. Vide, ou sans AuthUpstream : le
	// serveur MCP n'est pas monté.
	PublicAPIURL string
	// PublicWebURL, facultative, est l'adresse de l'app web : la page qui
	// décrit le serveur MCP y vit (/assistant.html).
	PublicWebURL string
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
	discordKey := getenv("AGORA_DISCORD_PUBLIC_KEY")
	if discordKey != "" {
		if _, err := hex.DecodeString(discordKey); err != nil || len(discordKey) != 2*ed25519.PublicKeySize {
			return Config{}, errors.New("AGORA_DISCORD_PUBLIC_KEY: 64 caractères hexadécimaux attendus")
		}
	}
	authUpstream := getenv("AGORA_AUTH_UPSTREAM")
	if authUpstream != "" {
		parsed, err := url.Parse(authUpstream)
		if err != nil || (parsed.Scheme != "http" && parsed.Scheme != "https") || parsed.Host == "" {
			return Config{}, fmt.Errorf("AGORA_AUTH_UPSTREAM %q: http(s) URL expected", authUpstream)
		}
	}
	publicAPI, err := publicURL("AGORA_PUBLIC_API_URL", getenv("AGORA_PUBLIC_API_URL"))
	if err != nil {
		return Config{}, err
	}
	publicWeb, err := publicURL("AGORA_PUBLIC_WEB_URL", getenv("AGORA_PUBLIC_WEB_URL"))
	if err != nil {
		return Config{}, err
	}
	appID := getenv("AGORA_DISCORD_APPLICATION_ID")
	if appID != "" && !isSnowflake(appID) {
		return Config{}, errors.New("AGORA_DISCORD_APPLICATION_ID: identifiant numérique attendu")
	}
	return Config{
		HTTPAddr:               addr,
		DatabaseURL:            databaseURL,
		DiscordPublicKey:       discordKey,
		DiscordBotToken:        getenv("AGORA_DISCORD_BOT_TOKEN"),
		DiscordApplicationID:   appID,
		ICSAllowPrivateNetwork: allowPrivate,
		AuthUpstream:           authUpstream,
		PublicAPIURL:           publicAPI,
		PublicWebURL:           publicWeb,
	}, nil
}

// publicURL valide une adresse publique : une origine (schéma et hôte, sans
// chemin), en https hors du poste local. Vide reste vide.
func publicURL(name, raw string) (string, error) {
	if raw == "" {
		return "", nil
	}
	parsed, err := url.Parse(raw)
	if err != nil || parsed.Host == "" || (parsed.Path != "" && parsed.Path != "/") || parsed.RawQuery != "" {
		return "", fmt.Errorf("%s %q: origine http(s) attendue, sans chemin", name, raw)
	}
	local := parsed.Hostname() == "localhost" || parsed.Hostname() == "127.0.0.1"
	if parsed.Scheme != "https" && !(local && parsed.Scheme == "http") {
		return "", fmt.Errorf("%s %q: https attendu hors du poste local", name, raw)
	}
	return strings.TrimRight(raw, "/"), nil
}

// isSnowflake dit si s est un identifiant Discord (entier décimal).
func isSnowflake(s string) bool {
	if len(s) == 0 || len(s) > 20 {
		return false
	}
	for _, r := range s {
		if r < '0' || r > '9' {
			return false
		}
	}
	return true
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
