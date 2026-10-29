// nv-cicd-demo: a tiny HTTP service for the NeuVector CI/CD demo.
// GET /        -> version string
// GET /healthz -> 200 ok
package main

import (
	"fmt"
	"log"
	"net/http"
)

// version is set at build time: -ldflags "-X main.version=<version>"
var version = "dev"

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		fmt.Fprintf(w, "nv-cicd-demo %s\n", version)
	})
	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "ok")
	})
	log.Printf("nv-cicd-demo %s listening on :8080", version)
	log.Fatal(http.ListenAndServe(":8080", nil))
}
