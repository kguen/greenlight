package main

import (
	"net/http"

	"github.com/go-chi/chi/v5"
)

func (app *application) routes() *chi.Mux {
	r := chi.NewRouter()

	r.NotFound(app.notFoundResponse)
	r.MethodNotAllowed(app.methodNotAllowedResponse)

	r.Use(app.recoverPanic, app.enableCORS, app.rateLimit, app.authenticate)

	r.Route("/v1", func(r chi.Router) {
		r.Get("/healthcheck", app.healthCheckHandler)

		r.Route("/movies", func(r chi.Router) {
			r.Group(func(r chi.Router) {
				r.Use(func(next http.Handler) http.Handler {
					return app.requirePermission("movies:read", next)
				})
				r.Get("/", app.listMoviesHandler)
				r.Get("/{id}", app.showMovieHandler)
			})
			r.Group(func(r chi.Router) {
				r.Use(func(next http.Handler) http.Handler {
					return app.requirePermission("movies:write", next)
				})
				r.Post("/", app.createMovieHandler)
				r.Patch("/{id}", app.updateMovieHandler)
				r.Delete("/{id}", app.deleteMovieHandler)
			})
		})
		r.Route("/users", func(r chi.Router) {
			r.Post("/", app.registerUserHandler)
			r.Put("/activated", app.activateUserHandler)
		})
		r.Post("/tokens/authentication", app.createAuthenticationTokenHandler)
	})
	return r
}
