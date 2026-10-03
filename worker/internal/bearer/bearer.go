// Package bearer lit, SANS en vérifier la signature, la charge d'un jeton
// GoTrue présenté en « Authorization: Bearer ».
//
// Choix non évident : ne pas vérifier est voulu. La lecture ne sert qu'à
// refuser davantage — la garde des routes de compte (authgate) écarte tout
// jeton porteur de client_id, le serveur MCP écarte tout jeton qui n'en porte
// pas — et c'est GoTrue, ou PostgREST, qui juge ensuite la signature. Un
// jeton forgé ne gagne donc rien à mentir sur ses claims.
//
// Invariant : ne rien journaliser du jeton.
//
//	if c, err := bearer.Read(bearer.FromHeader(r.Header.Get("Authorization"))); err == nil && c.ClientID != "" {
//		// jeton d'un assistant IA
//	}
package bearer

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"strings"
)

// Claims porte ce que le worker lit d'un jeton GoTrue.
type Claims struct {
	Sub      string `json:"sub"`
	ClientID string `json:"client_id"`
	Exp      int64  `json:"exp"`
	Scope    string `json:"scope"`
}

// FromHeader rend le jeton d'un en-tête Authorization, ou "" s'il n'y en a pas.
func FromHeader(header string) string {
	fields := strings.Fields(header)
	if len(fields) != 2 || !strings.EqualFold(fields[0], "bearer") {
		return ""
	}
	return fields[1]
}

// Read lit la charge d'un JWT.
func Read(token string) (Claims, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return Claims{}, errors.New("bearer: jeton mal formé")
	}
	payload, err := base64.RawURLEncoding.DecodeString(strings.TrimRight(parts[1], "="))
	if err != nil {
		return Claims{}, errors.New("bearer: charge illisible")
	}
	var c Claims
	if err := json.Unmarshal(payload, &c); err != nil {
		return Claims{}, errors.New("bearer: charge illisible")
	}
	return c, nil
}
