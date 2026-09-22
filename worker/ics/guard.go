package ics

import (
	"errors"
	"net/netip"
	"syscall"
)

// errBlockedAddress signale une connexion refusée vers une adresse non
// publique.
var errBlockedAddress = errors.New("ics: blocked address")

// blockedPrefixes complète les catégories de netip (boucle locale, réseaux
// privés, lien local, multidiffusion, adresse nulle) par les plages qu'elles
// ne couvrent pas. NAT64, 6to4 et Teredo embarquent une IPv4 : ils
// pourraient mener au réseau interne par un détour.
var blockedPrefixes = []netip.Prefix{
	netip.MustParsePrefix("0.0.0.0/8"),       // « ce réseau »
	netip.MustParsePrefix("100.64.0.0/10"),   // NAT des opérateurs (CGNAT)
	netip.MustParsePrefix("192.0.0.0/24"),    // affectations IETF
	netip.MustParsePrefix("192.0.2.0/24"),    // documentation
	netip.MustParsePrefix("198.18.0.0/15"),   // bancs d'essai
	netip.MustParsePrefix("198.51.100.0/24"), // documentation
	netip.MustParsePrefix("203.0.113.0/24"),  // documentation
	netip.MustParsePrefix("240.0.0.0/4"),     // réservé, diffusion comprise
	netip.MustParsePrefix("64:ff9b::/96"),    // NAT64
	netip.MustParsePrefix("64:ff9b:1::/48"),  // NAT64 local
	netip.MustParsePrefix("2001::/32"),       // Teredo
	netip.MustParsePrefix("2001:db8::/32"),   // documentation
	netip.MustParsePrefix("2002::/16"),       // 6to4
}

// isPublic dit si une connexion vers addr est permise. Une IPv4 écrite en
// IPv6 (::ffff:10.0.0.1) est jugée sur son IPv4.
func isPublic(addr netip.Addr) bool {
	addr = addr.Unmap()
	if !addr.IsValid() || addr.IsLoopback() || addr.IsPrivate() || addr.IsUnspecified() ||
		addr.IsLinkLocalUnicast() || addr.IsLinkLocalMulticast() ||
		addr.IsInterfaceLocalMulticast() || addr.IsMulticast() {
		return false
	}
	for _, prefix := range blockedPrefixes {
		if prefix.Contains(addr) {
			return false
		}
	}
	return true
}

// guardDial est le contrôle de net.Dialer : appelé pour chaque connexion,
// après la résolution DNS, avec l'adresse réellement composée. allowPrivate
// lève le contrôle (développement et tests seulement).
func guardDial(allowPrivate bool) func(network, address string, _ syscall.RawConn) error {
	return func(_, address string, _ syscall.RawConn) error {
		if allowPrivate {
			return nil
		}
		addrPort, err := netip.ParseAddrPort(address)
		if err != nil || !isPublic(addrPort.Addr()) {
			return errBlockedAddress
		}
		return nil
	}
}
