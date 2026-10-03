package discord

import "time"

// Fuseau des tests du bot : les récaps et /dispo se lisent à l'heure de Paris.
var paris = mustLoad("Europe/Paris")

func mustLoad(name string) *time.Location {
	loc, err := time.LoadLocation(name)
	if err != nil {
		panic(err)
	}
	return loc
}
