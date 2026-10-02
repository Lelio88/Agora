// Command worker est le service de fond d'Agora : dépliage des rdv
// récurrents, relecture des agendas iCal, bot Discord (commandes, récaps et
// rappels), et passerelle d'auth devant GoTrue (paquet authgate).
//
// « worker register-commands » inscrit les commandes du bot auprès de
// Discord, puis rend la main : à relancer après toute modification de
// discord.Definitions.
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

	"github.com/Lelio88/agora/worker/authgate"
	"github.com/Lelio88/agora/worker/discord"
	"github.com/Lelio88/agora/worker/ics"
	"github.com/Lelio88/agora/worker/internal/config"
	"github.com/Lelio88/agora/worker/internal/database"
	"github.com/Lelio88/agora/worker/internal/httpx"
	"github.com/Lelio88/agora/worker/recurrence"
)

const (
	readHeaderTimeout = 5 * time.Second
	// Corps lus en entier vite (64 Kio au plus) ; écriture assez longue pour
	// une requête relayée à GoTrue (30 s) ; connexions inactives fermées.
	// Le worker sert des routes publiques (passerelle d'auth) : un client
	// lent ne doit pas garder une connexion indéfiniment.
	readTimeout     = 10 * time.Second
	writeTimeout    = 40 * time.Second
	idleTimeout     = 60 * time.Second
	shutdownTimeout = 10 * time.Second
	// Dépliage complet périodique : fait glisser la fenêtre des occurrences.
	fullRefreshInterval = 6 * time.Hour
	notificationBuffer  = 256
	// Relève des flux dus : l'échéance de chacun est tenue par la base
	// (30 min après une relecture réussie), la relève ne fait que la guetter.
	icsPollInterval = time.Minute
	// Relève des récaps et rappels Discord : leur échéance est tenue par la
	// base, à la minute près.
	discordPublishInterval = time.Minute
	discordHTTPTimeout     = 10 * time.Second
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
	if len(os.Args) > 1 && os.Args[1] == "register-commands" {
		return registerCommands(cfg, logger)
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
	discordStore := discord.NewPgStore(pool)
	if cfg.DiscordPublicKey != "" {
		bot := discord.NewBot(discordStore, time.Now, logger)
		interactions, err = discord.NewHandler(cfg.DiscordPublicKey, bot.Commands(), time.Now)
		if err != nil {
			return fmt.Errorf("discord: %w", err)
		}
		logger.Info("discord interactions ready")
	}
	// Récaps et rappels : seulement avec le jeton du bot.
	if cfg.DiscordBotToken != "" {
		poster := discord.NewRESTPoster(&http.Client{Timeout: discordHTTPTimeout}, discord.APIBase, cfg.DiscordBotToken)
		publisher := discord.NewPublisher(discordStore, poster, time.Now, logger)
		background.Add(1)
		go func() {
			defer background.Done()
			publisher.Run(ctx, discordPublishInterval)
		}()
		logger.Info("discord publishing ready")
	}
	// Passerelle d'auth : seulement si l'adresse de GoTrue est donnée.
	var authGate *authgate.Gate
	var authHandler http.Handler
	if cfg.AuthUpstream != "" {
		authGate, err = authgate.New(authgate.Options{Upstream: cfg.AuthUpstream, Logger: logger})
		if err != nil {
			return fmt.Errorf("auth gate: %w", err)
		}
		authHandler = authGate
		logger.Info("auth gate ready")
	}
	srv := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           httpx.NewRouter(interactions, authHandler),
		ReadHeaderTimeout: readHeaderTimeout,
		ReadTimeout:       readTimeout,
		WriteTimeout:      writeTimeout,
		IdleTimeout:       idleTimeout,
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
	if authGate != nil {
		authGate.Wait()
	}
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

// registerCommands inscrit les commandes du bot auprès de Discord.
func registerCommands(cfg config.Config, logger *slog.Logger) error {
	if cfg.DiscordApplicationID == "" || cfg.DiscordBotToken == "" {
		return errors.New("register-commands: AGORA_DISCORD_APPLICATION_ID et AGORA_DISCORD_BOT_TOKEN sont requis")
	}
	ctx, cancel := context.WithTimeout(context.Background(), discordHTTPTimeout)
	defer cancel()
	client := &http.Client{Timeout: discordHTTPTimeout}
	if err := discord.RegisterCommands(ctx, client, discord.APIBase, cfg.DiscordApplicationID, cfg.DiscordBotToken); err != nil {
		return err
	}
	logger.Info("discord commands registered", "count", len(discord.Definitions()))
	return nil
}

// signal1 dépose un signal s'il n'y en a pas déjà un en attente.
func signal1(ch chan<- struct{}) {
	select {
	case ch <- struct{}{}:
	default:
	}
}
