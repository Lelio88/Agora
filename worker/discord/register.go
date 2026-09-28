package discord

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
)

// Inscription des commandes auprès de Discord (worker register-commands) :
// une seule requête PUT remplace l'ensemble des commandes globales, ce qui
// rend l'opération idempotente.
//
// Les noms de base sont français ; l'anglais passe par name_localizations.
// Discord renvoie toujours le nom de base dans l'interaction : c'est lui que
// Bot.Commands indexe.

const (
	optionString  = 3
	optionInteger = 4
	optionBoolean = 5

	// Contexte : en salon de serveur (0) et en message privé avec le bot (1).
	contextGuild     = 0
	contextBotDM     = 1
	installGuild     = 0
	manageChannelsID = "16"
)

func localized(fr, en string) map[string]string {
	return map[string]string{"fr": fr, "en-US": en, "en-GB": en}
}

func option(kind int, name, en, descFR, descEN string, required bool) map[string]any {
	return map[string]any{
		"type":                      kind,
		"name":                      name,
		"name_localizations":        map[string]string{"en-US": en, "en-GB": en},
		"description":               descFR,
		"description_localizations": localized(descFR, descEN),
		"required":                  required,
	}
}

func bounded(o map[string]any, low, high int) map[string]any {
	o["min_value"] = low
	o["max_value"] = high
	return o
}

// Definitions rend les commandes publiées par le bot.
func Definitions() []map[string]any {
	manage := func(c map[string]any) map[string]any {
		c["default_member_permissions"] = manageChannelsID
		c["contexts"] = []int{contextGuild}
		return c
	}
	command := func(name, en, descFR, descEN string, options ...map[string]any) map[string]any {
		return map[string]any{
			"name":                      name,
			"name_localizations":        map[string]string{"en-US": en, "en-GB": en},
			"description":               descFR,
			"description_localizations": localized(descFR, descEN),
			"integration_types":         []int{installGuild},
			"contexts":                  []int{contextGuild, contextBotDM},
			"options":                   append([]map[string]any{}, options...),
		}
	}
	durations := option(optionInteger, "duree", "duration", "Durée minimale, en minutes", "Minimum length, in minutes", true)
	durations["choices"] = []map[string]any{
		{"name": "30 min", "value": 30}, {"name": "1 h", "value": 60}, {"name": "1 h 30", "value": 90},
		{"name": "2 h", "value": 120}, {"name": "3 h", "value": 180},
	}
	return []map[string]any{
		manage(command("relier", "link", "Relier ce salon à un groupe Agora", "Link this channel to an Agora group",
			option(optionString, "code", "code", "Le code affiché dans l'app", "The code shown in the app", true))),
		manage(command("delier", "unlink", "Délier ce salon de son groupe Agora", "Unlink this channel from its Agora group")),
		command("agenda", "agenda", "Ton agenda, ou celui du groupe de ce salon (visible de toi seul)",
			"Your agenda, or this channel's group agenda (visible to you only)",
			bounded(option(optionInteger, "jours", "days", "Nombre de jours (7 par défaut)", "Number of days (7 by default)", false), 1, maxAgendaDays)),
		command("dispo", "free", "Les créneaux libres pour tout le groupe de ce salon",
			"Free slots for the whole group of this channel",
			durations,
			bounded(option(optionInteger, "jours", "days", "Sur combien de jours (7 par défaut)", "Over how many days (7 by default)", false), 1, maxFreeDays),
			bounded(option(optionInteger, "debut", "from", "Pas avant cette heure (9 par défaut)", "Not before this hour (9 by default)", false), 0, 23),
			bounded(option(optionInteger, "fin", "until", "Pas après cette heure (22 par défaut)", "Not after this hour (22 by default)", false), 1, 24),
			option(optionBoolean, "weekend", "weekend", "Inclure le week-end (oui par défaut)", "Include weekends (yes by default)", false)),
	}
}

// RegisterCommands remplace les commandes globales de l'application.
func RegisterCommands(ctx context.Context, client *http.Client, base, applicationID, token string) error {
	body, err := json.Marshal(Definitions())
	if err != nil {
		return fmt.Errorf("encode commands: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPut,
		base+"/applications/"+applicationID+"/commands", bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Authorization", "Bot "+token)
	req.Header.Set("Content-Type", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("register commands: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()
	detail, _ := io.ReadAll(io.LimitReader(resp.Body, 4<<10))
	if resp.StatusCode/100 != 2 {
		// Ici le corps aide : Discord y décrit la commande refusée.
		return fmt.Errorf("register commands: status %d: %s", resp.StatusCode, detail)
	}
	return nil
}
