package assistant

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/modelcontextprotocol/go-sdk/auth"

	"github.com/Lelio88/agora/worker/internal/bearer"
)

const (
	// verifyTimeout borne l'appel à GoTrue : un assistant attend, pas plus.
	verifyTimeout = 5 * time.Second
	maxUserBody   = 64 << 10
)

// NewVerifier rend le vérificateur des jetons d'assistant. Il ne garde aucun
// secret : c'est GoTrue qui juge, par GET /user, la signature, l'expiration
// et l'existence de la session — révoquer l'accès dans l'app supprime la
// session, et le jeton tombe aussitôt (pas au bout d'une heure).
//
// Seul un jeton porteur de client_id (délivré à un assistant par le serveur
// OAuth) est admis : une session de l'application n'a rien à faire ici.
func NewVerifier(upstream string, client *http.Client) auth.TokenVerifier {
	userURL := strings.TrimRight(upstream, "/") + "/user"
	return func(ctx context.Context, token string, _ *http.Request) (*auth.TokenInfo, error) {
		c, err := bearer.Read(token)
		if err != nil || c.ClientID == "" || c.Sub == "" || c.Exp == 0 {
			return nil, fmt.Errorf("%w: jeton d'assistant attendu", auth.ErrInvalidToken)
		}
		userID, err := askGoTrue(ctx, client, userURL, token)
		if err != nil {
			return nil, err
		}
		if userID != c.Sub {
			return nil, fmt.Errorf("%w: jeton incohérent", auth.ErrInvalidToken)
		}
		return &auth.TokenInfo{
			UserID:     userID,
			Expiration: time.Unix(c.Exp, 0),
			Scopes:     strings.Fields(c.Scope),
			Extra:      map[string]any{"client_id": c.ClientID},
		}, nil
	}
}

// askGoTrue rend l'identifiant du compte si GoTrue accepte le jeton.
func askGoTrue(ctx context.Context, client *http.Client, userURL, token string) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, verifyTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, userURL, nil)
	if err != nil {
		return "", fmt.Errorf("vérification du jeton : %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("vérification du jeton : %w", err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxUserBody))
	if err != nil {
		return "", fmt.Errorf("vérification du jeton : %w", err)
	}
	switch {
	case resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusForbidden:
		return "", fmt.Errorf("%w: refusé par le serveur d'autorisation", auth.ErrInvalidToken)
	case resp.StatusCode != http.StatusOK:
		return "", fmt.Errorf("vérification du jeton : GoTrue a répondu %d", resp.StatusCode)
	}
	var user struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(body, &user); err != nil || user.ID == "" {
		return "", errors.New("vérification du jeton : réponse de GoTrue illisible")
	}
	return user.ID, nil
}
