package main

import (
	"fmt"
	"net/http"
)

func (app *application) logError(r *http.Request, err error) {
	app.logger.PrintError(err, map[string]string{
		"request_method": r.Method,
		"request_url":    r.URL.String(),
	})
}

func (app *application) errorResponse(w http.ResponseWriter, r *http.Request, status int, message interface{}) {
	data := envelope{"error": message}

	err := app.writeJSON(w, status, data, nil)
	if err != nil {
		app.logError(r, err)
		w.WriteHeader(http.StatusInternalServerError)
	}
}

func (app *application) serverErrorResponse(w http.ResponseWriter, r *http.Request, err error) {
	app.logError(r, err)
	app.errorResponse(w, r, http.StatusInternalServerError, "the server encountered a problem and could not process your request")
}

func (app *application) notFoundResponse(w http.ResponseWriter, r *http.Request) {
	app.errorResponse(w, r, http.StatusNotFound, "the requested resource could not be found")
}

func (app *application) methodNotAllowedResponse(w http.ResponseWriter, r *http.Request) {
	app.errorResponse(w, r, http.StatusMethodNotAllowed, fmt.Sprintf("the %s method is not supported for this resource", r.Method))
}

func (app *application) badRequestResponse(w http.ResponseWriter, r *http.Request, err error) {
	app.errorResponse(w, r, http.StatusBadRequest, err.Error())
}

func (app *application) failedValidationResponse(w http.ResponseWriter, r *http.Request, errors map[string]string) {
	app.errorResponse(w, r, http.StatusUnprocessableEntity, errors)
}

func (app *application) editConflictResponse(w http.ResponseWriter, r *http.Request) {
	app.errorResponse(w, r, http.StatusConflict, "unable to update the record due to an edit conflict, please try again")
}

func (app *application) rateLimitExceededResponse(w http.ResponseWriter, r *http.Request) {
	app.errorResponse(w, r, http.StatusTooManyRequests, "rate limit exceeded")
}

func (app *application) invalidCredentialsResponse(w http.ResponseWriter, r *http.Request) {
	app.errorResponse(w, r, http.StatusUnauthorized, "invalid authentication credentials")
}

func (app *application) invalidAuthenticationTokenResponse(w http.ResponseWriter, r *http.Request) {
	// remind the client that we expect them to authenticate using a bearer token
	w.Header().Set("WWW-Authenticate", "Bearer")
	app.errorResponse(w, r, http.StatusUnauthorized, "invalid or missing authentication token")
}

func (app *application) authenticationRequiredResponse(w http.ResponseWriter, r *http.Request) {
	app.errorResponse(w, r, http.StatusUnauthorized, "you must be authenticated to access this resource")
}

func (app *application) inactiveAccountResponse(w http.ResponseWriter, r *http.Request) {
	app.errorResponse(w, r, http.StatusForbidden, "your user account must be activated to access this resource")
}

func (app *application) notPermittedResponse(w http.ResponseWriter, r *http.Request) {
	app.errorResponse(w, r, http.StatusForbidden, "your user account doesn't have the necessary permissions to access this resource")
}
