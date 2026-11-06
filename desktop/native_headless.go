package main

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/signal"
	"time"
)

// Diagnostics never launch a browser, apply updates, or control native lifetime.
func diagnosticHandler(app *App) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		if err := reportTemplate.Execute(w, app.snapshot()); err != nil {
			http.Error(w, err.Error(), 500)
		}
	})
	mux.HandleFunc("/logo.png", func(w http.ResponseWriter, r *http.Request) {
		b, _ := assets.ReadFile("logo.png")
		w.Header().Set("Content-Type", "image/png")
		_, _ = w.Write(b)
	})
	mux.HandleFunc("/refresh", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "POST only", 405)
			return
		}
		if r.Header.Get("Origin") != "" && r.Header.Get("Origin") != "http://"+r.Host {
			http.Error(w, "same-origin only", 403)
			return
		}
		app.refresh()
		fmt.Fprint(w, app.snapshot().Loaded.UnixNano())
	})
	mux.HandleFunc("/setgame", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "POST only", 405)
			return
		}
		if r.Header.Get("Origin") != "" && r.Header.Get("Origin") != "http://"+r.Host {
			http.Error(w, "same-origin only", 403)
			return
		}
		r.Body = http.MaxBytesReader(w, r.Body, 8192)
		g := NormalizeGame(r.FormValue("game"))
		if g == "" {
			http.Error(w, "Not a WoW Forever folder", 400)
			return
		}
		app.setGame(g)
		saveGame(g)
		app.refresh()
		http.Redirect(w, r, "/", http.StatusSeeOther)
	})
	mux.HandleFunc("/stamp", func(w http.ResponseWriter, r *http.Request) { fmt.Fprint(w, app.snapshot().Loaded.UnixNano()) })
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		host, _, err := net.SplitHostPort(r.Host)
		if err != nil || host != "127.0.0.1" {
			http.Error(w, "loopback host required", 403)
			return
		}
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Cache-Control", "no-store")
		mux.ServeHTTP(w, r)
	})
}

func serveDiagnostic(app *App, port int) error {
	ln, err := net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", port))
	if err != nil {
		return err
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()
	server := &http.Server{Handler: diagnosticHandler(app), ReadHeaderTimeout: 5 * time.Second}
	go func() { <-ctx.Done(); _ = server.Close() }()
	fmt.Printf("Relax Coach %s diagnostic HTTP: http://%s/\n", Version, ln.Addr())
	err = server.Serve(ln)
	if errors.Is(err, http.ErrServerClosed) {
		return nil
	}
	return err
}
