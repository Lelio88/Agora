package discord

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

type recordingPoster struct {
	posts []string
	err   error
}

func (p *recordingPoster) Post(_ context.Context, channel, content string) error {
	p.posts = append(p.posts, channel+"|"+content)
	return p.err
}

func TestTickPublishesRemindersAndRecaps(t *testing.T) {
	store := &fakeStore{
		reminders: []Reminder{{ChannelID: "10", Timezone: "Europe/Paris", Locale: "fr", GroupName: "Potes",
			Title: "Resto", Location: "Chez Paul", Start: time.Date(2026, 10, 5, 17, 0, 0, 0, time.UTC)}},
		recaps: []Recap{{GroupID: "g", GroupName: "Potes", ChannelID: "10", Timezone: "Europe/Paris",
			Locale: "fr", Kind: "weekly", Slot: monday}},
		recapAgenda: []AgendaItem{{UserID: "u-ben", DisplayName: "Ben", Level: "busy",
			Start: time.Date(2026, 10, 6, 8, 0, 0, 0, time.UTC), End: time.Date(2026, 10, 6, 9, 0, 0, 0, time.UTC)}},
	}
	poster := &recordingPoster{}
	NewPublisher(store, poster, nil, silent()).Tick(context.Background())

	if len(poster.posts) != 2 {
		t.Fatalf("publications = %v", poster.posts)
	}
	if !strings.Contains(poster.posts[0], "Rappel — Potes : Resto (Chez Paul), lun. 5 oct. à 19:00") {
		t.Errorf("rappel = %q", poster.posts[0])
	}
	if !strings.Contains(poster.posts[1], "Récap de la semaine — Potes") || !strings.Contains(poster.posts[1], "Ben : occupé") {
		t.Errorf("récap = %q", poster.posts[1])
	}
}

func TestTickKeepsGoingWhenDiscordFails(t *testing.T) {
	store := &fakeStore{reminders: []Reminder{
		{ChannelID: "1", Timezone: "UTC", Title: "A", Start: monday},
		{ChannelID: "2", Timezone: "UTC", Title: "B", Start: monday},
	}}
	poster := &recordingPoster{err: errors.New("503")}
	NewPublisher(store, poster, nil, silent()).Tick(context.Background())
	if len(poster.posts) != 2 {
		t.Fatalf("un échec ne doit pas arrêter les suivants : %v", poster.posts)
	}
}

func TestRESTPosterSendsAsTheBotWithoutMentions(t *testing.T) {
	var got struct {
		path, auth string
		body       map[string]any
	}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		got.path, got.auth = r.URL.Path, r.Header.Get("Authorization")
		_ = json.NewDecoder(r.Body).Decode(&got.body)
		w.WriteHeader(http.StatusOK)
	}))
	defer srv.Close()

	err := NewRESTPoster(srv.Client(), srv.URL, "jeton").Post(context.Background(), "42", "bonjour")
	if err != nil {
		t.Fatalf("Post : %v", err)
	}
	if got.path != "/channels/42/messages" || got.auth != "Bot jeton" || got.body["content"] != "bonjour" {
		t.Fatalf("requête = %+v", got)
	}
	mentions, _ := got.body["allowed_mentions"].(map[string]any)
	if parse, _ := mentions["parse"].([]any); mentions == nil || len(parse) != 0 {
		t.Fatalf("allowed_mentions = %v, attendu aucune mention", got.body["allowed_mentions"])
	}
}

func TestRESTPosterReportsARefusal(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusForbidden)
	}))
	defer srv.Close()
	if err := NewRESTPoster(srv.Client(), srv.URL, "jeton").Post(context.Background(), "42", "x"); err == nil {
		t.Fatal("un 403 doit remonter")
	}
}

func TestRegisterCommandsReplacesTheWholeSet(t *testing.T) {
	var method, path string
	var commands []map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		method, path = r.Method, r.URL.Path
		_ = json.NewDecoder(r.Body).Decode(&commands)
		w.WriteHeader(http.StatusOK)
	}))
	defer srv.Close()

	if err := RegisterCommands(context.Background(), srv.Client(), srv.URL, "123", "jeton"); err != nil {
		t.Fatalf("RegisterCommands : %v", err)
	}
	if method != http.MethodPut || path != "/applications/123/commands" {
		t.Fatalf("%s %s", method, path)
	}
	names := map[string]bool{}
	for _, c := range commands {
		names[c["name"].(string)] = true
	}
	for name := range newTestBot(&fakeStore{}).Commands() {
		if !names[name] {
			t.Errorf("la commande %q est servie mais pas inscrite", name)
		}
	}
}
