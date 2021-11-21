package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	addr := flag.String("addr", ":9000", "Server address")
	requestType := flag.String("request-type", "simple", "CORS request type (simple|preflight)")
	flag.Parse()

	html, err := os.ReadFile(fmt.Sprintf("./cmd/examples/cors/%s.html", *requestType))
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("starting server on %s", *addr)
	err = http.ListenAndServe(*addr, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write(html)
	}))
	if err != nil {
		log.Fatal(err)
	}
}
