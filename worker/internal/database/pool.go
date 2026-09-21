// Package database ouvre le pool de connexions Postgres du worker.
//
// Choix non évident : un petit pool (MaxConns = 4). Le worker traite une
// série à la fois, et chaque connexion Postgres coûte de la mémoire sur un
// serveur partagé où chaque service tient dans sa mem_limit. L'écoute LISTEN
// a sa propre connexion, hors pool.
package database

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

const maxConnections = 4

// NewPool ouvre le pool et vérifie la connexion : une base injoignable fait
// échouer le démarrage plutôt que la première requête.
func NewPool(ctx context.Context, databaseURL string) (*pgxpool.Pool, error) {
	cfg, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("parse database url: %w", err)
	}
	cfg.MaxConns = maxConnections
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
