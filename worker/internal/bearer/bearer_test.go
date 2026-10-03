package bearer

import (
	"encoding/base64"
	"testing"
)

func TestFromHeader(t *testing.T) {
	tests := []struct{ name, header, want string }{
		{name: "bearer", header: "Bearer abc", want: "abc"},
		{name: "case_ignored", header: "bearer abc", want: "abc"},
		{name: "other_scheme", header: "Basic abc", want: ""},
		{name: "empty", header: "", want: ""},
		{name: "too_many_parts", header: "Bearer a b", want: ""},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := FromHeader(tt.header); got != tt.want {
				t.Fatalf("FromHeader(%q) = %q, want %q", tt.header, got, tt.want)
			}
		})
	}
}

func TestRead(t *testing.T) {
	payload := base64.RawURLEncoding.EncodeToString([]byte(`{"sub":"u1","client_id":"c1","exp":42,"scope":"email"}`))
	c, err := Read("h." + payload + ".s")
	if err != nil || c.Sub != "u1" || c.ClientID != "c1" || c.Exp != 42 || c.Scope != "email" {
		t.Fatalf("Read = %+v, %v", c, err)
	}
	padded := base64.URLEncoding.EncodeToString([]byte(`{"sub":"u1"}`))
	if c, err := Read("h." + padded + ".s"); err != nil || c.Sub != "u1" {
		t.Fatalf("une charge complétée par « = » : %+v, %v", c, err)
	}
	for _, bad := range []string{"", "a.b", "a.!!!.c", "a." + base64.RawURLEncoding.EncodeToString([]byte("pas du json")) + ".c"} {
		if _, err := Read(bad); err == nil {
			t.Fatalf("Read(%q) devait échouer", bad)
		}
	}
}
