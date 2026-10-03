package assistant

import (
	"os"
	"regexp"
	"slices"
	"testing"
)

// La page publique (app/web/assistant.html) nomme exactement les outils que
// le serveur annonce, dans chacune de ses deux langues.
func TestPublicPageNamesEveryTool(t *testing.T) {
	page, err := os.ReadFile("../../app/web/assistant.html")
	if err != nil {
		t.Fatal(err)
	}
	var named []string
	for _, m := range regexp.MustCompile(`<code class="outil">([a-z_]+)</code>`).FindAllSubmatch(page, -1) {
		named = append(named, string(m[1]))
	}
	want := slices.Concat(Tools, Tools) // français puis anglais
	if !slices.Equal(named, want) {
		t.Fatalf("outils de la page = %v\nattendu (FR puis EN, dans l'ordre du serveur) = %v", named, want)
	}
}
