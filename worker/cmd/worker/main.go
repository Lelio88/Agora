// Command worker est le service de fond d'Agora : dépliage des rdv
// récurrents, puis relecture des agendas iCal et bot Discord.
//
// Choix non évident : un seul binaire pour toutes ces tâches, en Go, pour
// tenir en ~15 Mo sur un serveur partagé où chaque service porte sa
// mem_limit. Il parle directement à Postgres, et non via PostgREST, sous le
// rôle restreint agora_worker, pour LISTEN/NOTIFY et le schéma private.
//
// Invariants :
//   - un arrêt (SIGINT/SIGTERM) laisse aux requêtes en cours le temps de se
//     terminer avant de rendre la main ;
//   - la base de fuseaux horaires est embarquée (time/tzdata) : l'image
//     Docker minimale n'en a pas, et sans elle aucune série ne se déplierait.
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"
	_ "time/tzdata"

	"github.com/Lelio88/agora/worker/internal/config"
	"github.com/Lelio88/agora/worker/internal/database"
	"github.com/Lelio88/agora/worker/internal/httpx"
	"github.com/Lelio88/agora/worker/recurrence"
)

const (
	readHeaderTimeout = 5 * time.Second
	shutdownTimeout   = 10 * time.Second
	// Dépliage complet périodique : fait glisser la fenêtre des occurrences.
	fullRefreshInterval = 6 * time.Hour
	notificationBuffer  = 256
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

	pool, err := database.NewPool(ctx, cfg.DatabaseURL)
	if err != nil {
		return fmt.Errorf("database %s: %w", cfg.RedactedDatabaseURL(), err)
	}
	defer pool.Close()

	var background sync.WaitGroup
	startRecurrence(ctx, &background, cfg.DatabaseURL, recurrence.NewPgStore(pool), logger)

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
		stop()
		background.Wait()
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return fmt.Errorf("serve http: %w", err)
	case <-ctx.Done():
	}

	logger.Info("shutting down")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), shutdownTimeout)
	defer cancel()
	err = srv.Shutdown(shutdownCtx)
	background.Wait()
	if err != nil {
		return fmt.Errorf("shutdown http: %w", err)
	}
	return nil
}

// startRecurrence lance l'écoute des séries modifiées et leur traitement.
// Chaque (re)connexion de l'écoute déclenche un dépliage complet, qui sert
// aussi de dépliage initial au démarrage.
func startRecurrence(ctx context.Context, wg *sync.WaitGroup, databaseURL string, store recurrence.Store, logger *slog.Logger) {
	service := recurrence.NewService(store, time.Now, logger)
	notifications := make(chan string, notificationBuffer)
	refreshAll := make(chan struct{}, 1)
	requestRefreshAll := func() {
		select {
		case refreshAll <- struct{}{}:
		default: // un dépliage complet est déjà demandé
		}
	}
	wg.Add(2)
	go func() {
		defer wg.Done()
		recurrence.Listen(ctx, databaseURL, notifications, requestRefreshAll, logger)
	}()
	go func() {
		defer wg.Done()
		service.Run(ctx, notifications, refreshAll, fullRefreshInterval)
	}()
}
