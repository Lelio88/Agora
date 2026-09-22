package ics

import (
	"errors"
	"net/netip"
	"testing"
	"time"
)

func TestIsPublic(t *testing.T) {
	tests := []struct {
		addr string
		want bool
	}{
		{addr: "8.8.8.8", want: true},
		{addr: "2a00:1450:4007:80e::200e", want: true},
		{addr: "127.0.0.1"},
		{addr: "10.0.0.1"},
		{addr: "172.16.5.4"},
		{addr: "192.168.1.1"},
		{addr: "169.254.169.254"}, // métadonnées des hébergeurs
		{addr: "100.64.0.1"},
		{addr: "0.0.0.0"},
		{addr: "255.255.255.255"},
		{addr: "224.0.0.1"},
		{addr: "::1"},
		{addr: "::"},
		{addr: "fe80::1"},
		{addr: "fc00::1"},
		{addr: "::ffff:10.0.0.1"},     // IPv4 écrite en IPv6
		{addr: "64:ff9b::a00:1"},      // NAT64 vers 10.0.0.1
		{addr: "2002:a00:1::1"},       // 6to4 vers 10.0.0.1
		{addr: "2001:0:4136:e378::1"}, // Teredo
	}
	for _, tt := range tests {
		t.Run(tt.addr, func(t *testing.T) {
			if got := isPublic(netip.MustParseAddr(tt.addr)); got != tt.want {
				t.Errorf("isPublic(%s) = %v, want %v", tt.addr, got, tt.want)
			}
		})
	}
}

func TestGuardDial(t *testing.T) {
	strict, lenient := guardDial(false), guardDial(true)
	if err := strict("tcp", "93.184.215.14:443", nil); err != nil {
		t.Errorf("public address refused: %v", err)
	}
	for _, address := range []string{"127.0.0.1:443", "[::1]:443", "not an address"} {
		if err := strict("tcp", address, nil); !errors.Is(err, errBlockedAddress) {
			t.Errorf("%s: error = %v, want errBlockedAddress", address, err)
		}
	}
	if err := lenient("tcp", "127.0.0.1:443", nil); err != nil {
		t.Errorf("private network allowed, yet refused: %v", err)
	}
}

func TestResolveZone(t *testing.T) {
	tests := []struct {
		tzid string
		want string
	}{
		{tzid: "Europe/Paris", want: "Europe/Paris"},
		{tzid: `"Europe/Paris"`, want: "Europe/Paris"},
		{tzid: "Romance Standard Time", want: "Europe/Paris"},
		{tzid: "/softwarestudio.org/Olson_20011030_5/America/New_York", want: "America/New_York"},
		{tzid: "Heure de Mars"},
		{tzid: "Local"},
		{tzid: ""},
	}
	for _, tt := range tests {
		t.Run(tt.tzid, func(t *testing.T) {
			loc, ok := resolveZone(tt.tzid)
			switch {
			case tt.want == "" && ok:
				t.Errorf("resolveZone(%q) = %v, want unknown", tt.tzid, loc)
			case tt.want != "" && (!ok || loc.String() != tt.want):
				t.Errorf("resolveZone(%q) = %v, %v, want %s", tt.tzid, loc, ok, tt.want)
			}
		})
	}
}

// Chaque zone de la table doit exister dans la base de fuseaux embarquée et
// passer la contrainte de la base.
func TestWindowsZonesAreValid(t *testing.T) {
	for windows, iana := range windowsZones {
		if _, err := time.LoadLocation(iana); err != nil {
			t.Errorf("%s → %s: %v", windows, iana, err)
		}
		if !zoneNamePattern.MatchString(iana) {
			t.Errorf("%s → %s: refused by the events.timezone constraint", windows, iana)
		}
	}
}
