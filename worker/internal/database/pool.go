// Package database ouvre le pool de connexions Postgres du worker.
//
// Choix non évident : de petits pools. Le principal (MaxConns = 4) sert les
// tâches de fond, qui traitent une série à la fois ; celui des assistants IA
// (AssistantConnections) est à part, pour qu'une rafale d'appels MCP
// n'affame ni les récurrences, ni l'iCal, ni Discord. Chaque connexion
// Postgres coûte de la mémoire sur un serveur partagé où chaque service tient
// dans sa mem_limit. L'écoute LISTEN a sa propre connexion, hors pool.
package database

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Tailles des pools.
const (
	BackgroundConnections = 4
	AssistantConnections  = 2
)

// NewPool ouvre un pool de maxConns connexions et vérifie la connexion : une
// base injoignable fait échouer le démarrage plutôt que la première requête.
func NewPool(ctx context.Context, databaseURL string, maxConns int32) (*pgxpool.Pool, error) {
	cfg, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("parse database url: %w", err)
	}
	cfg.MaxConns = maxConns
	cfg.ConnConfig.RuntimeParams["application_name"] = "agora-worker"
	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("open pool: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping database: %w", err)
	}
	return pool, nil
}
