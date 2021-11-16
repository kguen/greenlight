package main

import (
	"github.com/go-chi/chi/v5"
)

func (app *application) routes() *chi.Mux {
	r := chi.NewRouter()

	r.NotFound(app.notFoundResponse)
	r.MethodNotAllowed(app.methodNotAllowedResponse)

	r.Route("/v1", func(r chi.Router) {
		r.Get("/healthcheck", app.healthCheckHandler)
		r.Post("/movies", app.createMovieHandler)
		r.Get("/movies/{id}", app.showMovieHandler)
		r.Patch("/movies/{id}", app.updateMovieHandler)
		r.Delete("/movies/{id}", app.deleteMovieHandler)
	})
	return r
}
