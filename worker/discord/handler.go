// Package discord reçoit les interactions du bot Agora : Discord appelle le
// worker en HTTP, sans connexion permanente à sa passerelle.
//
// Choix non évidents :
//
//   - Discord signe chaque appel (Ed25519 sur horodatage + corps) et exige
//     qu'un appel mal signé reçoive 401 : c'est ainsi qu'il valide l'URL
//     d'interactions. La clé publique de l'application est donc le seul
//     titre d'entrée ; sans elle, le point d'entrée n'est pas monté ;
//   - l'horodatage doit être frais (cinq minutes) : une signature captée ne
//     se rejoue pas indéfiniment ;
//   - toute réponse à une commande est éphémère (flag 64), visible du seul
//     demandeur. C'est la règle de vie privée côté Discord : un salon a une
//     audience plus large que le groupe (§6 de docs/architecture.md) ;
//   - les messages naissent bilingues, choisis sur la locale du demandeur
//     (Text), comme les chaînes de l'app naissent dans les deux ARB.
//
// Invariant : rien n'est lu en base avant que la signature soit vérifiée.
//
//	h, err := discord.NewHandler(publicKeyHex, map[string]discord.CommandFunc{
//		"agenda": agendaCommand,
//	}, time.Now)
package discord

import (
	"context"
	"crypto/ed25519"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"
)

const (
	// Corps accepté : une interaction Discord tient très en deçà.
	maxBody = 64 << 10
	// Écart toléré entre l'horodatage signé et l'heure du worker.
	freshness = 5 * time.Minute

	typePing            = 1
	typeApplicationCmd  = 2
	replyPong           = 1
	replyMessage        = 4
	flagEphemeral       = 64
	signatureHeader     = "X-Signature-Ed25519"
	timestampHeaderName = "X-Signature-Timestamp"
)

// Interaction est ce qu'une commande a besoin de savoir de l'appel.
type Interaction struct {
	// Command est le nom de la commande (« agenda », « dispo »).
	Command string
	// UserID est l'identifiant Discord du demandeur, qui sert à retrouver
	// son compte Agora dans auth.identities.
	UserID string
	// GuildID et ChannelID sont vides en message privé.
	GuildID   string
	ChannelID string
	// Locale est celle du client Discord du demandeur (« fr », « en-US »).
	Locale string
	// Options porte les valeurs des options de la commande, par nom.
	Options map[string]string
}

// Reply est la réponse rendue au demandeur, toujours éphémère.
type Reply struct {
	Content string
}

// CommandFunc traite une commande. Le contexte est celui de la requête :
// Discord attend une réponse en trois secondes.
type CommandFunc func(ctx context.Context, in Interaction) Reply

// Handler sert le point d'entrée des interactions.
type Handler struct {
	key      ed25519.PublicKey
	commands map[string]CommandFunc
	now      func() time.Time
}

// NewHandler construit le point d'entrée à partir de la clé publique
// hexadécimale de l'application Discord. Une clé absente ou mal formée est
// une erreur : mieux vaut ne pas démarrer que d'accepter n'importe quel appel.
func NewHandler(publicKeyHex string, commands map[string]CommandFunc, now func() time.Time) (*Handler, error) {
	key, err := hex.DecodeString(publicKeyHex)
	if err != nil {
		return nil, errors.New("discord: la clé publique n'est pas de l'hexadécimal")
	}
	if len(key) != ed25519.PublicKeySize {
		return nil, errors.New("discord: la clé publique ne fait pas 32 octets")
	}
	if now == nil {
		now = time.Now
	}
	return &Handler{key: key, commands: commands, now: now}, nil
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	body, err := h.readSigned(w, r)
	if err != nil {
		writeStatus(w, err)
		return
	}
	var payload struct {
		Type   int    `json:"type"`
		Locale string `json:"locale"`
		Guild  string `json:"guild_id"`
		Chan   string `json:"channel_id"`
		Data   struct {
			Name    string `json:"name"`
			Options []struct {
				Name  string          `json:"name"`
				Value json.RawMessage `json:"value"`
			} `json:"options"`
		} `json:"data"`
		Member struct {
			User struct {
				ID string `json:"id"`
			} `json:"user"`
		} `json:"member"`
		User struct {
			ID string `json:"id"`
		} `json:"user"`
	}
	if err := json.Unmarshal(body, &payload); err != nil {
		http.Error(w, "corps illisible", http.StatusBadRequest)
		return
	}

	switch payload.Type {
	case typePing:
		writeJSON(w, map[string]any{"type": replyPong})
	case typeApplicationCmd:
		// En salon, le demandeur est dans member ; en message privé, dans user.
		userID := payload.Member.User.ID
		if userID == "" {
			userID = payload.User.ID
		}
		in := Interaction{
			Command:   payload.Data.Name,
			UserID:    userID,
			GuildID:   payload.Guild,
			ChannelID: payload.Chan,
			Locale:    payload.Locale,
			Options:   make(map[string]string, len(payload.Data.Options)),
		}
		for _, option := range payload.Data.Options {
			value := string(option.Value)
			var text string
			if json.Unmarshal(option.Value, &text) == nil {
				value = text
			}
			in.Options[option.Name] = value
		}
		command, ok := h.commands[in.Command]
		if !ok {
			writeReply(w, Reply{Content: Text(in.Locale,
				"Cette commande n'existe pas (ou plus).",
				"This command does not exist (any more).")})
			return
		}
		writeReply(w, command(r.Context(), in))
	default:
		// Aucun bouton ni formulaire n'est publié : un tel appel n'est pas attendu.
		http.Error(w, "interaction non prise en charge", http.StatusBadRequest)
	}
}

// errTooLarge et errUnauthorized portent le statut à rendre, sans détail :
// un appel mal signé n'apprend rien de plus.
var (
	errTooLarge     = errors.New("corps trop grand")
	errUnauthorized = errors.New("signature invalide")
)

// readSigned rend le corps une fois la signature de Discord vérifiée.
func (h *Handler) readSigned(w http.ResponseWriter, r *http.Request) ([]byte, error) {
	signature, err := hex.DecodeString(r.Header.Get(signatureHeader))
	if err != nil || len(signature) != ed25519.SignatureSize {
		return nil, errUnauthorized
	}
	timestamp := r.Header.Get(timestampHeaderName)
	seconds, err := strconv.ParseInt(timestamp, 10, 64)
	if err != nil {
		return nil, errUnauthorized
	}
	if delta := h.now().Sub(time.Unix(seconds, 0)); delta > freshness || delta < -freshness {
		return nil, errUnauthorized
	}
	body, err := readAll(w, r)
	if err != nil {
		return nil, err
	}
	if !ed25519.Verify(h.key, append([]byte(timestamp), body...), signature) {
		return nil, errUnauthorized
	}
	return body, nil
}

func readAll(w http.ResponseWriter, r *http.Request) ([]byte, error) {
	limited := http.MaxBytesReader(w, r.Body, maxBody)
	defer func() { _ = limited.Close() }()
	body := make([]byte, 0, 4096)
	buffer := make([]byte, 4096)
	for {
		n, err := limited.Read(buffer)
		body = append(body, buffer[:n]...)
		if err != nil {
			var tooLarge *http.MaxBytesError
			if errors.As(err, &tooLarge) {
				return nil, errTooLarge
			}
			if errors.Is(err, context.Canceled) {
				return nil, errUnauthorized
			}
			return body, nil
		}
	}
}

func writeStatus(w http.ResponseWriter, err error) {
	if errors.Is(err, errTooLarge) {
		http.Error(w, "corps trop grand", http.StatusRequestEntityTooLarge)
		return
	}
	http.Error(w, "signature invalide", http.StatusUnauthorized)
}

func writeReply(w http.ResponseWriter, reply Reply) {
	writeJSON(w, map[string]any{
		"type": replyMessage,
		"data": map[string]any{"content": reply.Content, "flags": flagEphemeral},
	})
}

func writeJSON(w http.ResponseWriter, payload any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(payload)
}

// Text choisit la version française ou anglaise d'un message selon la locale
// du demandeur. Tout ce que le bot dit naît dans les deux langues, comme les
// chaînes de l'app.
func Text(locale, fr, en string) string {
	if len(locale) >= 2 && locale[:2] == "fr" {
		return fr
	}
	return en
}
