package assistant

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"slices"
	"strings"
	"testing"
	"time"
)

const public = "https://api.agora.test"

// newTestServer monte le serveur entier (vérification, MCP, ressource) sur un
// faux GoTrue qui accepte Ada.
func newTestServer(t *testing.T, store Store) *httptest.Server {
	t.Helper()
	goTrue, _ := fakeGoTrue(t, http.StatusOK, ada)
	svc, err := New(Options{
		PublicURL: public, AuthUpstream: goTrue.URL, DocsURL: "https://agora.test/assistant.html",
		Store: store, HTTPClient: goTrue.Client(), Now: func() time.Time { return monday },
	})
	if err != nil {
		t.Fatal(err)
	}
	mux := http.NewServeMux()
	mux.Handle(ResourcePath, svc.MCP)
	mux.Handle(MetadataPath, svc.ResourceMetadata)
	srv := httptest.NewServer(mux)
	t.Cleanup(srv.Close)
	return srv
}

func call(t *testing.T, srv *httptest.Server, token, body string) (*http.Response, map[string]any) {
	t.Helper()
	req, _ := http.NewRequest(http.MethodPost, srv.URL+ResourcePath, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json, text/event-stream")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	var out map[string]any
	_ = json.Unmarshal(raw, &out)
	return resp, out
}

func TestWithoutTokenTheClientIsSentToTheAuthorizationServer(t *testing.T) {
	srv := newTestServer(t, newFake())
	resp, _ := call(t, srv, "", `{"jsonrpc":"2.0","id":1,"method":"tools/list"}`)
	challenge := resp.Header.Get("WWW-Authenticate")
	if resp.StatusCode != http.StatusUnauthorized || !strings.Contains(challenge, `resource_metadata="`+public+MetadataPath+`"`) {
		t.Fatalf("statut %d, WWW-Authenticate %q", resp.StatusCode, challenge)
	}
}

func TestResourceMetadataNeverOffersOpenID(t *testing.T) {
	srv := newTestServer(t, newFake())
	resp, err := srv.Client().Get(srv.URL + MetadataPath)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	var meta struct {
		Resource              string   `json:"resource"`
		AuthorizationServers  []string `json:"authorization_servers"`
		ScopesSupported       []string `json:"scopes_supported"`
		ResourceDocumentation string   `json:"resource_documentation"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&meta); err != nil {
		t.Fatal(err)
	}
	if meta.Resource != public+"/mcp" || !slices.Equal(meta.AuthorizationServers, []string{public + "/auth/v1"}) {
		t.Fatalf("métadonnées = %+v", meta)
	}
	if !slices.Equal(meta.ScopesSupported, []string{"email"}) {
		t.Fatalf("scopes = %v : jamais openid (GoTrue en HS256 brûlerait le code)", meta.ScopesSupported)
	}
}

func TestToolsAreListedAndCalledForTheTokenOwner(t *testing.T) {
	srv := newTestServer(t, newFake())
	token := assistantToken(ada)

	resp, out := call(t, srv, token, `{"jsonrpc":"2.0","id":1,"method":"tools/list"}`)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("tools/list : statut %d, %v", resp.StatusCode, out)
	}
	var names []string
	for _, tool := range out["result"].(map[string]any)["tools"].([]any) {
		names = append(names, tool.(map[string]any)["name"].(string))
	}
	if !sameSet(names, Tools) {
		t.Fatalf("outils annoncés %v, attendu %v", names, Tools)
	}

	_, out = call(t, srv, token, `{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"mes_groupes","arguments":{}}}`)
	result := out["result"].(map[string]any)
	groups := result["structuredContent"].(map[string]any)["groupes"].([]any)
	if result["isError"] == true || len(groups) != 1 || groups[0].(map[string]any)["nom"] != "Potes" {
		t.Fatalf("mes_groupes = %v", result)
	}

	_, out = call(t, srv, token, `{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"agenda_du_groupe","arguments":{"groupe":"Rando"}}}`)
	result = out["result"].(map[string]any)
	text := result["content"].([]any)[0].(map[string]any)["text"].(string)
	if result["isError"] != true || !strings.Contains(text, "Aucun groupe « Rando »") {
		t.Fatalf("un refus rédigé doit atteindre l'assistant tel quel : %v", result)
	}
}

func TestAnInternalErrorStaysInside(t *testing.T) {
	store := newFake()
	store.err = io.ErrUnexpectedEOF
	srv := newTestServer(t, store)
	_, out := call(t, srv, assistantToken(ada), `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"mon_agenda","arguments":{}}}`)
	result := out["result"].(map[string]any)
	text := result["content"].([]any)[0].(map[string]any)["text"].(string)
	if result["isError"] != true || strings.Contains(text, "EOF") || !strings.Contains(text, "Erreur interne") {
		t.Fatalf("erreur interne = %q", text)
	}
}

func sameSet(a, b []string) bool {
	a, b = slices.Clone(a), slices.Clone(b)
	slices.Sort(a)
	slices.Sort(b)
	return slices.Equal(a, b)
}
