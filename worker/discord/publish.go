package discord

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"time"
)

// Publication des récaps et des rappels dans les salons reliés, par l'API
// REST de Discord et le jeton du bot : pas de connexion permanente à la
// passerelle.
//
// Un récap ou un rappel est réclamé en base AVANT l'envoi : une panne de
// Discord en perd un, elle n'en publie jamais deux. Le contenu d'un récap
// passe par private.discord_recap_agenda, qui plafonne les rdv personnels à
// « occupé ».

// APIBase est la racine de l'API REST de Discord (version figée).
const APIBase = "https://discord.com/api/v10"

// Poster envoie un message dans un salon.
type Poster interface {
	Post(ctx context.Context, channelID, content string) error
}

// RESTPoster publie par l'API REST avec le jeton du bot.
type RESTPoster struct {
	client *http.Client
	base   string
	token  string
}

// NewRESTPoster construit le client. base vaut APIBase hors des tests.
func NewRESTPoster(client *http.Client, base, token string) *RESTPoster {
	return &RESTPoster{client: client, base: base, token: token}
}

// Post publie content dans le salon, sans notifier personne.
func (p *RESTPoster) Post(ctx context.Context, channelID, content string) error {
	body, err := json.Marshal(map[string]any{
		"content":          content,
		"allowed_mentions": noMentions,
	})
	if err != nil {
		return fmt.Errorf("encode message: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		p.base+"/channels/"+channelID+"/messages", bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Authorization", "Bot "+p.token)
	req.Header.Set("Content-Type", "application/json")
	resp, err := p.client.Do(req)
	if err != nil {
		return fmt.Errorf("post message: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()
	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 64<<10))
	if resp.StatusCode/100 != 2 {
		// Le statut suffit : le corps d'une erreur Discord n'apprend rien
		// d'utile au journal et pourrait citer le message.
		return fmt.Errorf("post message: status %d", resp.StatusCode)
	}
	return nil
}

// Publisher réclame et publie récaps et rappels, à intervalle régulier.
type Publisher struct {
	store  Store
	poster Poster
	now    func() time.Time
	logger *slog.Logger
}

// NewPublisher construit la publication.
func NewPublisher(store Store, poster Poster, now func() time.Time, logger *slog.Logger) *Publisher {
	if now == nil {
		now = time.Now
	}
	return &Publisher{store: store, poster: poster, now: now, logger: logger}
}

// Run publie toutes les interval jusqu'à l'annulation de ctx.
func (p *Publisher) Run(ctx context.Context, interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		p.Tick(ctx)
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		}
	}
}

// Tick publie les rappels puis les récaps dus. Une erreur est journalisée
// sans arrêter la boucle : la prochaine relève réessaie.
func (p *Publisher) Tick(ctx context.Context) {
	reminders, err := p.store.ClaimReminders(ctx)
	if err != nil {
		p.logger.Error("discord reminders", "err", err)
	}
	for _, r := range reminders {
		if err := p.poster.Post(ctx, r.ChannelID, reminderMessage(r)); err != nil {
			p.logger.Warn("discord reminder not sent", "channel", r.ChannelID, "err", err)
		}
	}
	recaps, err := p.store.ClaimRecaps(ctx)
	if err != nil {
		p.logger.Error("discord recaps", "err", err)
	}
	for _, r := range recaps {
		if err := p.publishRecap(ctx, r); err != nil {
			p.logger.Warn("discord recap not sent", "channel", r.ChannelID, "err", err)
		}
	}
}

func (p *Publisher) publishRecap(ctx context.Context, r Recap) error {
	loc := location(r.Timezone)
	span := 24 * time.Hour
	if r.Kind == "weekly" {
		span = 7 * 24 * time.Hour
	}
	items, err := p.store.RecapAgenda(ctx, r.GroupID, r.Slot, r.Slot.Add(span))
	if err != nil {
		return err
	}
	return p.poster.Post(ctx, r.ChannelID, recapMessage(r, items, loc))
}

func recapMessage(r Recap, items []AgendaItem, loc *time.Location) string {
	header := Text(r.Locale,
		fmt.Sprintf("**Récap du jour — %s**", plain(r.GroupName)),
		fmt.Sprintf("**Today's recap — %s**", plain(r.GroupName)))
	if r.Kind == "weekly" {
		header = Text(r.Locale,
			fmt.Sprintf("**Récap de la semaine — %s**", plain(r.GroupName)),
			fmt.Sprintf("**This week's recap — %s**", plain(r.GroupName)))
	}
	if len(items) == 0 {
		return header + "\n" + nothing(r.Locale)
	}
	return lines(header, agendaLines(items, loc, r.Locale), r.Locale)
}

func reminderMessage(r Reminder) string {
	loc := location(r.Timezone)
	start := r.Start.In(loc)
	what := plain(r.Title)
	if r.Location != "" {
		what += " (" + plain(r.Location) + ")"
	}
	return Text(r.Locale,
		fmt.Sprintf("⏰ Rappel — %s : %s, %s à %s.", plain(r.GroupName), what, dayLabel(start, r.Locale), start.Format("15:04")),
		fmt.Sprintf("⏰ Reminder — %s: %s, %s at %s.", plain(r.GroupName), what, dayLabel(start, r.Locale), start.Format("15:04")))
}
