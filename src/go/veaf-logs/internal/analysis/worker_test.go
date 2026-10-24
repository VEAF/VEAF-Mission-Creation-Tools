package analysis

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
)

// fakeWorker answers /analyze with the given status and SSE body, and keeps the request.
// The handler runs on the server's goroutine: what it keeps is guarded.
func fakeWorker(t *testing.T, status int, body string) (*httptest.Server, func() (map[string]any, http.Header)) {
	t.Helper()
	got := map[string]any{}
	var header http.Header
	var mu sync.Mutex
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		defer mu.Unlock()
		header = r.Header.Clone()
		data, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(data, &got)
		w.WriteHeader(status)
		_, _ = io.WriteString(w, body)
	}))
	t.Cleanup(srv.Close)
	return srv, func() (map[string]any, http.Header) {
		mu.Lock()
		defer mu.Unlock()
		return got, header
	}
}

func TestWorkerAssemblesTheStreamedFragments(t *testing.T) {
	srv, last := fakeWorker(t, 200, "data: {\"text\":\"Le \"}\n\n: comment\ndata: pas du json\n\ndata:{\"text\":\"journal\"}\r\n\r\ndata: [DONE]\n")
	matches := []WorkerMatch{{ID: "damage_model", Label: "Modèle de dégâts", Help: "Cosmétique.", Count: 2}}
	got, err := AnalyseExcerpt(srv.URL, "l'extrait", matches, "pourquoi ?", "fr")
	if err != nil || got != "Le journal" {
		t.Fatalf("got %q, %v", got, err)
	}
	req, header := last()
	if header.Get("X-VEAF-Client") != "logs" || !strings.HasPrefix(header.Get("Content-Type"), "application/json") {
		t.Fatalf("headers %v", header)
	}
	if req["excerpt"] != "l'extrait" || req["question"] != "pourquoi ?" || req["lang"] != "fr" {
		t.Fatalf("body %v", req)
	}
	m := req["matches"].([]any)[0].(map[string]any)
	if m["id"] != "damage_model" || m["count"] != float64(2) || m["help"] != "Cosmétique." {
		t.Fatalf("matches %v", m)
	}
}

func TestWorkerLanguageIsFrenchUnlessEnglish(t *testing.T) {
	srv, last := fakeWorker(t, 200, "")
	_, _ = AnalyseExcerpt(srv.URL, "x", nil, "", "de")
	req, _ := last()
	if req["lang"] != "fr" {
		t.Fatalf("lang %v", req["lang"])
	}
	if req["matches"] == nil {
		t.Fatal("matches must be a list, not null")
	}
}

func TestWorkerFailuresAreMessages(t *testing.T) {
	srv, _ := fakeWorker(t, 503, "")
	if _, err := AnalyseExcerpt(srv.URL, "x", nil, "", "fr"); err == nil || err.Error() != "Analyse en ligne indisponible (code 503)." {
		t.Fatalf("503: %v", err)
	}
	srv, _ = fakeWorker(t, 200, "data: {\"text\":\"a\",\"error\":0}\ndata: {\"error\":\"quota épuisé\"}\n")
	if _, err := AnalyseExcerpt(srv.URL, "x", nil, "", "fr"); err == nil || err.Error() != "quota épuisé" {
		t.Fatalf("error payload: %v", err)
	}
	closed := httptest.NewServer(http.NotFoundHandler())
	url := closed.URL
	closed.Close()
	if _, err := AnalyseExcerpt(url, "x", nil, "", "fr"); err == nil || err.Error() != unreachable {
		t.Fatalf("unreachable: %v", err)
	}
}

func TestOnlineFillsTheModelSection(t *testing.T) {
	srv, _ := fakeWorker(t, 200, "data: {\"text\":\"  réponse  \"}\n")
	a := Online(Analysis{}, srv.URL, "")
	if a.Commentary != "réponse" || a.ModelError != "" {
		t.Fatalf("%+v", a)
	}
	srv, _ = fakeWorker(t, 200, "data: [DONE]\n")
	if a := Online(Analysis{}, srv.URL, ""); a.ModelError != nothingReturned || a.Commentary != "" {
		t.Fatalf("empty answer: %+v", a)
	}
	srv, _ = fakeWorker(t, 500, "")
	if a := Online(Analysis{Commentary: "ancienne"}, srv.URL, ""); a.ModelError == "" || a.Commentary != "" {
		t.Fatalf("failure: %+v", a)
	}
}
