// Command worker est le service de fond d'Agora : relecture des agendas iCal,
// dépliage des rdv récurrents, bot Discord (commandes, récaps, rappels).
//
// Choix non évident : un seul binaire pour toutes ces tâches, en Go, pour
// tenir en ~15 Mo sur un serveur partagé où chaque service porte sa
// mem_limit. Il parle directement à Postgres, et non via PostgREST, pour
// accéder au schéma private (URL iCal, résolution de visibilité) et à
// LISTEN/NOTIFY.
//
// Invariant : un arrêt (SIGINT/SIGTERM) laisse aux requêtes en cours le temps
// de se terminer avant de rendre la main.
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/Lelio88/agora/worker/internal/config"
	"github.com/Lelio88/agora/worker/internal/httpx"
)

const (
	readHeaderTimeout = 5 * time.Second
	shutdownTimeout   = 10 * time.Second
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	if err := run(logger); err != nil {
		logger.Error("worker stopped", "err", err)
		os.Exit(1)
	}
}

func run(logger *slog.Logger) error {
	cfg, err := config.Load(os.Getenv)
	if err != nil {
		return fmt.Errorf("load config: %w", err)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	srv := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           httpx.NewRouter(),
		ReadHeaderTimeout: readHeaderTimeout,
	}
	serveErr := make(chan error, 1)
	go func() {
		logger.Info("listening", "addr", cfg.HTTPAddr)
		serveErr <- srv.ListenAndServe()
	}()

	select {
	case err := <-serveErr:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return fmt.Errorf("serve http: %w", err)
	case <-ctx.Done():
	}

	logger.Info("shutting down")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), shutdownTimeout)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		return fmt.Errorf("shutdown http: %w", err)
	}
	return nil
}
