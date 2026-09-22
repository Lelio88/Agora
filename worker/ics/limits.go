package ics

import "bytes"

// Le décodeur de go-ical n'est pas écrit pour une donnée hostile :
//   - il est récursif : une imbrication BEGIN sans fin épuise la pile ;
//   - il construit chaque valeur de paramètre octet par octet, par
//     concaténation : un paramètre de quelques Mio prendrait des heures de
//     processeur (temps quadratique) ;
//   - il panique sur certaines lignes mal formées (paramètre sans « : »,
//     guillemet suivi d'un caractère inattendu).
//
// withinDecoderLimits écarte les deux premiers cas avant le décodage, en une
// seule passe linéaire sur les lignes dépliées ; Parse rattrape le troisième.

const (
	maxNesting = 8
	// maxHeadBytes borne la partie « nom;paramètres » d'une ligne (jusqu'au
	// premier « : » hors guillemets). Un TZID ou un ALTREP y tiennent large.
	maxHeadBytes = 4096
)

var (
	beginName = []byte("BEGIN")
	endName   = []byte("END")
)

// withinDecoderLimits dit si body peut être confié au décodeur.
func withinDecoderLimits(body []byte) bool {
	var s headScanner
	for line := range bytes.Lines(body) {
		line = bytes.TrimRight(line, "\r\n")
		// Une ligne qui commence par une espace prolonge la précédente
		// (pliage RFC 5545), comme le lit le décodeur.
		if len(line) > 0 && (line[0] == ' ' || line[0] == '\t') {
			if !s.feed(line[1:]) {
				return false
			}
			continue
		}
		if !s.endLine() || !s.feed(line) {
			return false
		}
	}
	return s.endLine()
}

// headScanner suit l'imbrication et, pour la ligne dépliée en cours, la
// longueur de sa partie « nom;paramètres ».
type headScanner struct {
	depth     int
	name      []byte // les premiers octets du nom de propriété
	nameDone  bool
	headLen   int
	inQuote   bool
	colonSeen bool
}

// feed lit la suite de la ligne en cours ; faux si sa tête est trop longue.
// La valeur (après le « : ») n'est pas parcourue.
func (s *headScanner) feed(chunk []byte) bool {
	for _, c := range chunk {
		if s.colonSeen {
			return true
		}
		s.headLen++
		if s.headLen > maxHeadBytes {
			return false
		}
		switch {
		case c == '"':
			s.inQuote = !s.inQuote
		case c == ':' && !s.inQuote:
			s.colonSeen, s.nameDone = true, true
		case c == ';' && !s.inQuote:
			s.nameDone = true
		case !s.nameDone && len(s.name) <= len(beginName):
			s.name = append(s.name, c)
		}
	}
	return true
}

// endLine clôt la ligne en cours ; faux si elle ouvre un niveau de trop.
func (s *headScanner) endLine() bool {
	switch {
	case bytes.EqualFold(s.name, beginName):
		s.depth++
		if s.depth > maxNesting {
			return false
		}
	case bytes.EqualFold(s.name, endName):
		s.depth--
	}
	s.name, s.nameDone, s.headLen, s.inQuote, s.colonSeen = s.name[:0], false, 0, false, false
	return true
}
