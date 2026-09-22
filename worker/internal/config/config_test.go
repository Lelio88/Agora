package config

import (
	"strings"
	"testing"
)

const localURL = "postgresql://agora_worker:secret@127.0.0.1:55322/postgres"

// Clé publique Ed25519 de test : 32 octets, donc 64 caractères.
const discordKey = "1f8b4c2a9d7e6f5041322314150607f8e9dacbbc9d8e7f60514233241506f7e8"

func TestLoad(t *testing.T) {
	tests := []struct {
		name     string
		env      map[string]string
		wantAddr string
		// wantPrivate : contrôle SSRF levé (AGORA_ICS_ALLOW_PRIVATE_NETWORK).
		wantPrivate bool
		wantDiscord string
		wantErr     bool
	}{
		{
			name:     "defaults to port 8080",
			env:      map[string]string{"AGORA_DATABASE_URL": localURL},
			wantAddr: ":8080",
		},
		{
			name:     "reads the listen address",
			env:      map[string]string{"AGORA_DATABASE_URL": localURL, "AGORA_HTTP_ADDR": "127.0.0.1:9090"},
			wantAddr: "127.0.0.1:9090",
		},
		{
			name:    "rejects an address without port",
			env:     map[string]string{"AGORA_DATABASE_URL": localURL, "AGORA_HTTP_ADDR": "localhost"},
			wantErr: true,
		},
		{
			name:        "allows private feed addresses only when asked",
			env:         map[string]string{"AGORA_DATABASE_URL": localURL, "AGORA_ICS_ALLOW_PRIVATE_NETWORK": "true"},
			wantAddr:    ":8080",
			wantPrivate: true,
		},
		{
			name:    "rejects an unreadable private-network switch",
			env:     map[string]string{"AGORA_DATABASE_URL": localURL, "AGORA_ICS_ALLOW_PRIVATE_NETWORK": "maybe"},
			wantErr: true,
		},
		{
			name:    "requires the database URL",
			env:     map[string]string{},
			wantErr: true,
		},
		{
			name:    "rejects a database URL that is not postgres",
			env:     map[string]string{"AGORA_DATABASE_URL": "https://example.com"},
			wantErr: true,
		},
		{
			name: "reads the Discord public key",
			env: map[string]string{
				"AGORA_DATABASE_URL":       localURL,
				"AGORA_DISCORD_PUBLIC_KEY": discordKey,
			},
			wantAddr:    ":8080",
			wantDiscord: discordKey,
		},
		{
			name: "rejects a Discord key that is not 32 bytes",
			env: map[string]string{
				"AGORA_DATABASE_URL":       localURL,
				"AGORA_DISCORD_PUBLIC_KEY": "abcdef",
			},
			wantErr: true,
		},
		{
			name: "rejects a Discord key that is not hexadecimal",
			env: map[string]string{
				"AGORA_DATABASE_URL":       localURL,
				"AGORA_DISCORD_PUBLIC_KEY": strings.Repeat("z", 64),
			},
			wantErr: true,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cfg, err := Load(func(key string) string { return tt.env[key] })

			if tt.wantErr {
				if err == nil {
					t.Fatalf("Load() error = nil, want an error")
				}
				return
			}
			if err != nil {
				t.Fatalf("Load() error = %v", err)
			}
			if cfg.HTTPAddr != tt.wantAddr {
				t.Errorf("HTTPAddr = %q, want %q", cfg.HTTPAddr, tt.wantAddr)
			}
			if cfg.ICSAllowPrivateNetwork != tt.wantPrivate {
				t.Errorf("ICSAllowPrivateNetwork = %v, want %v", cfg.ICSAllowPrivateNetwork, tt.wantPrivate)
			}
			if cfg.DiscordPublicKey != tt.wantDiscord {
				t.Errorf("DiscordPublicKey = %q, want %q", cfg.DiscordPublicKey, tt.wantDiscord)
			}
			if cfg.DatabaseURL != localURL {
				t.Errorf("DatabaseURL = %q, want %q", cfg.DatabaseURL, localURL)
			}
		})
	}
}

func TestConfigNeverPrintsTheDatabasePassword(t *testing.T) {
	cfg, err := Load(func(key string) string {
		return map[string]string{"AGORA_DATABASE_URL": localURL}[key]
	})
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}

	if got := cfg.RedactedDatabaseURL(); got != "postgresql://agora_worker:xxxxx@127.0.0.1:55322/postgres" {
		t.Errorf("RedactedDatabaseURL() = %q", got)
	}
}
