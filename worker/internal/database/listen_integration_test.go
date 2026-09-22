//go:build integration

package database

import (
	"context"
	"io"
	"log/slog"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Exige la pile Supabase locale et AGORA_TEST_DATABASE_URL (rôle du worker) ;
// les notifications partent en postgres via AGORA_TEST_ADMIN_URL.
func TestListenDispatchesEachChannel(t *testing.T) {
	workerURL, adminURL := os.Getenv("AGORA_TEST_DATABASE_URL"), os.Getenv("AGORA_TEST_ADMIN_URL")
	if workerURL == "" || adminURL == "" {
		t.Fatal("AGORA_TEST_DATABASE_URL and AGORA_TEST_ADMIN_URL are required")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	admin, err := pgxpool.New(ctx, adminURL)
	if err != nil {
		t.Fatal(err)
	}
	defer admin.Close()

	got := make(chan [2]string, 2)
	connected := make(chan struct{}, 2)
	subscribe := func(channel string) Subscription {
		return Subscription{
			Channel:     channel,
			Deliver:     func(_ context.Context, payload string) { got <- [2]string{channel, payload} },
			OnConnected: func() { connected <- struct{}{} },
		}
	}
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	go Listen(ctx, workerURL, []Subscription{subscribe("agora_test_a"), subscribe("agora_test_b")}, logger)
	<-connected
	<-connected

	for _, n := range [][2]string{{"agora_test_b", "second"}, {"agora_test_a", "first"}} {
		if _, err := admin.Exec(ctx, `select pg_notify($1, $2)`, n[0], n[1]); err != nil {
			t.Fatal(err)
		}
		select {
		case received := <-got:
			if received != n {
				t.Errorf("received %v, want %v", received, n)
			}
		case <-ctx.Done():
			t.Fatalf("no notification on %s", n[0])
		}
	}
}
