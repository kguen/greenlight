package main

import (
	"github.com/go-chi/chi/v5"
)

func (app *application) routes() *chi.Mux {
	r := chi.NewRouter()

	r.NotFound(app.notFoundResponse)
	r.MethodNotAllowed(app.methodNotAllowedResponse)

	r.Use(app.recoverPanic)
	r.Use(app.rateLimit)

	r.Route("/v1", func(r chi.Router) {
		r.Get("/healthcheck", app.healthCheckHandler)

		r.Route("/movies", func(r chi.Router) {
			r.Get("/", app.listMoviesHandler)
			r.Post("/", app.createMovieHandler)
			r.Get("/{id}", app.showMovieHandler)
			r.Patch("/{id}", app.updateMovieHandler)
			r.Delete("/{id}", app.deleteMovieHandler)
		})
		r.Route("/users", func(r chi.Router) {
			r.Post("/", app.registerUserHandler)
			r.Put("/activated", app.activateUserHandler)
		})
	})
	return r
}
