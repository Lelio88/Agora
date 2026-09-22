package database

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5"
)

// Subscription associe un canal NOTIFY à son traitement.
type Subscription struct {
	// Channel est le nom du canal (LISTEN).
	Channel string
	// Deliver reçoit la charge utile de chaque notification. Il peut
	// bloquer : l'écoute attend, jusqu'à l'annulation de ctx.
	Deliver func(ctx context.Context, payload string)
	// OnConnected est appelé à chaque (re)connexion : les notifications
	// émises pendant la coupure sont perdues, il faut alors tout relire.
	OnConnected func()
}

const (
	listenInitialBackoff = time.Second
	listenMaxBackoff     = time.Minute
)

// Listen écoute les canaux de subscriptions sur UNE connexion dédiée (jamais
// une connexion du pool : un LISTEN resterait actif après sa restitution),
// et rend chaque notification au Deliver de son canal. Rend la main à
// l'annulation de ctx.
func Listen(ctx context.Context, databaseURL string, subscriptions []Subscription, logger *slog.Logger) {
	byChannel := make(map[string]Subscription, len(subscriptions))
	for _, s := range subscriptions {
		byChannel[s.Channel] = s
	}
	backoff := listenInitialBackoff
	for ctx.Err() == nil {
		err := listenOnce(ctx, databaseURL, byChannel, func() {
			backoff = listenInitialBackoff
			for _, s := range subscriptions {
				s.OnConnected()
			}
		})
		if ctx.Err() != nil {
			return
		}
		logger.Warn("listener disconnected", "err", err, "retry_in", backoff)
		select {
		case <-ctx.Done():
			return
		case <-time.After(backoff):
		}
		backoff = min(backoff*2, listenMaxBackoff)
	}
}

func listenOnce(ctx context.Context, databaseURL string, byChannel map[string]Subscription, onConnected func()) error {
	conn, err := pgx.Connect(ctx, databaseURL)
	if err != nil {
		return fmt.Errorf("connect: %w", err)
	}
	defer conn.Close(context.WithoutCancel(ctx))
	for channel := range byChannel {
		if _, err := conn.Exec(ctx, "listen "+pgx.Identifier{channel}.Sanitize()); err != nil {
			return fmt.Errorf("listen %s: %w", channel, err)
		}
	}
	onConnected()
	for {
		notification, err := conn.WaitForNotification(ctx)
		if err != nil {
			return fmt.Errorf("wait for notification: %w", err)
		}
		if s, ok := byChannel[notification.Channel]; ok {
			s.Deliver(ctx, notification.Payload)
		}
	}
}
