package config

import "testing"

func TestLoad(t *testing.T) {
	tests := []struct {
		name     string
		env      map[string]string
		wantAddr string
		wantErr  bool
	}{
		{name: "defaults to port 8080", env: map[string]string{}, wantAddr: ":8080"},
		{name: "reads the listen address", env: map[string]string{"AGORA_HTTP_ADDR": "127.0.0.1:9090"}, wantAddr: "127.0.0.1:9090"},
		{name: "rejects an address without port", env: map[string]string{"AGORA_HTTP_ADDR": "localhost"}, wantErr: true},
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
		})
	}
}
