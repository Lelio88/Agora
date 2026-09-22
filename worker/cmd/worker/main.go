// Command worker est le service de fond d'Agora : dépliage des rdv
// récurrents et relecture des agendas iCal, puis bot Discord.
//
// Choix non évident : un seul binaire pour toutes ces tâches, en Go, pour
// tenir en ~15 Mo sur un serveur partagé où chaque service porte sa
// mem_limit. Il parle directement à Postgres, et non via PostgREST, sous le
// rôle restreint agora_worker, pour LISTEN/NOTIFY et le schéma private.
//
// Les deux tâches partagent une seule connexion d'écoute (LISTEN) : chaque
// connexion Postgres coûte de la mémoire au serveur.
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

	"github.com/Lelio88/agora/worker/discord"
	"github.com/Lelio88/agora/worker/ics"
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
	// Relève des flux dus : l'échéance de chacun est tenue par la base
	// (30 min après une relecture réussie), la relève ne fait que la guetter.
	icsPollInterval = time.Minute
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

	if cfg.ICSAllowPrivateNetwork {
		logger.Warn("ics: private network allowed, SSRF guard disabled (development only)")
	}
	var background sync.WaitGroup
	subscriptions := []database.Subscription{
		startRecurrence(ctx, &background, recurrence.NewPgStore(pool), logger),
		startICS(ctx, &background, ics.NewPgStore(pool), ics.NewHTTPFetcher(cfg.ICSAllowPrivateNetwork), logger),
	}
	background.Add(1)
	go func() {
		defer background.Done()
		database.Listen(ctx, cfg.DatabaseURL, subscriptions, logger)
	}()

	// Le bot n'écoute que si l'application Discord a donné sa clé publique :
	// sans elle, aucune signature n'est vérifiable, donc rien n'est monté.
	var interactions http.Handler
	if cfg.DiscordPublicKey != "" {
		interactions, err = discord.NewHandler(cfg.DiscordPublicKey, nil, time.Now)
		if err != nil {
			return fmt.Errorf("discord: %w", err)
		}
		logger.Info("discord interactions ready")
	}
	srv := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           httpx.NewRouter(interactions),
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

// startRecurrence lance le traitement des séries modifiées et rend son
// abonnement. Chaque (re)connexion de l'écoute déclenche un dépliage
// complet, qui sert aussi de dépliage initial au démarrage.
func startRecurrence(ctx context.Context, wg *sync.WaitGroup, store recurrence.Store, logger *slog.Logger) database.Subscription {
	service := recurrence.NewService(store, time.Now, logger)
	notifications := make(chan string, notificationBuffer)
	refreshAll := make(chan struct{}, 1)
	wg.Add(1)
	go func() {
		defer wg.Done()
		service.Run(ctx, notifications, refreshAll, fullRefreshInterval)
	}()
	return database.Subscription{
		Channel: recurrence.Channel,
		Deliver: func(ctx context.Context, payload string) {
			select {
			case notifications <- payload:
			case <-ctx.Done():
			}
		},
		OnConnected: func() { signal1(refreshAll) },
	}
}

// startICS lance la relecture des flux iCal et rend son abonnement. Une
// notification ne fait que réveiller la relève : elle prend tous les flux
// dus, dont celui qui vient d'être ajouté ou relancé.
func startICS(ctx context.Context, wg *sync.WaitGroup, store ics.Store, fetcher ics.Fetcher, logger *slog.Logger) database.Subscription {
	service := ics.NewService(store, fetcher, time.Now, logger)
	wake := make(chan struct{}, 1)
	wg.Add(1)
	go func() {
		defer wg.Done()
		service.Run(ctx, wake, icsPollInterval)
	}()
	return database.Subscription{
		Channel:     ics.Channel,
		Deliver:     func(context.Context, string) { signal1(wake) },
		OnConnected: func() { signal1(wake) },
	}
}

// signal1 dépose un signal s'il n'y en a pas déjà un en attente.
func signal1(ch chan<- struct{}) {
	select {
	case ch <- struct{}{}:
	default:
	}
}
