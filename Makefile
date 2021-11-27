include .env
export

# ==================================================================================== #
# HELPERS
# ==================================================================================== #

## help: print this help message
.PHONY: help
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'

.PHONY: confirm
confirm:
	@echo -n 'Are you sure? [y/N] ' && read ans && [ $${ans:-N} = y ]

# ==================================================================================== #
# BUILD
# ==================================================================================== #

current_time = $(shell date --iso-8601=seconds)
git_description = $(shell git describe --always --dirty --tags --long) 
linker_flag = '-s -X main.buildTime=${current_time} -X main.version=${git_description}'

## build/api: build the cmd/api application
.PHONY: build/api
build/api:
	@echo 'Building cmd/api...'
	go build -ldflags=${linker_flag} -o=./bin/api ./cmd/api

## build/prod/api: build the cmd/api application for production server (linux)
.PHONY: build/prod/api
build/prod/api: build/api
	@echo 'Building cmd/api for production server...'
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags=${linker_flag} -o=./bin/linux_amd64/api ./cmd/api

## build/debug/api: build the cmd/api application with debug infomation
.PHONY: build/debug/api
build/debug/api:
	@echo 'Build cmd/api with debug info...'
	go build -o ./bin/debug/api -gcflags='all=-N -l' ./cmd/api

# ==================================================================================== #
# DEVELOPMENT
# ==================================================================================== #

## run/api: run the cmd/api application
.PHONY: run/api
run/api: build/api
	@./bin/api -db-dsn=${GREENLIGHT_DB_DSN} -smtp-username=${GREENLIGHT_SMTP_USERNAME} -smtp-password=${GREENLIGHT_SMTP_PASSWORD} -cors-trusted-origins=${GREENLIGHT_TRUSTED_ORIGINS}

## run/examples/cors: run the examples/cors application
.PHONY: run/examples/cors
run/examples/cors:
	go run ./cmd/examples/cors -request-type=${request_type}

## db/psql: connect to the database using psql
.PHONY: db/psql
db/psql:
	psql ${GREENLIGHT_DB_DSN}

## db/migrations/new name=$1: create a new database migration
.PHONY: db/migrations/new
db/migrations/new:
	@echo 'Creating migration files for ${name}...'
	migrate create -seq -ext .sql -dir ./migrations ${name}

## db/migrations/up: apply database migrations
.PHONY: db/migrations/up
db/migrations/up: confirm
	@echo 'Apply migrations...'
	migrate -path=./migrations -database=${GREENLIGHT_DB_DSN} up

## db/migrations/down version=$1: migrate database to a version
.PHONY: db/migrations/goto
db/migrations/goto:
	@echo 'Migrate to version ${version}...'
	migrate -path=./migrations -database=${GREENLIGHT_DB_DSN} goto ${version}

## db/migrations/force version=$1: force set database to a migration version
.PHONY: db/migrations/force
db/migrations/force:
	@echo 'Force version ${version}...'
	migrate -path=./migrations -database=${GREENLIGHT_DB_DSN} force ${version}

## db/migrations/down: rollback all migrations 
.PHONY: db/migrations/down
db/migrations/down:
	@echo 'Rollback all migrations...'
	migrate -path=./migrations -database=${GREENLIGHT_DB_DSN} down

# ==================================================================================== #
# QUALITY CONTROL
# ==================================================================================== #

## audit: tidy dependencies and format, vet and test all code
.PHONY: audit
audit: tidy
	@echo 'Formatting code...'
	go fmt ./...
	@echo 'Vetting code...'
	go vet ./...
	staticcheck ./...
	@echo 'Running tests...'
	go test -race -vet=off ./...

## vendor: tidy and vendor dependencies
.PHONY: vendor
vendor: tidy
	@echo 'Vendoring dependencies...'
	go mod vendor

## tidy: tidy dependencies
.PHONY: tidy
tidy:
	@echo 'Tidying and verifying module dependencies...'
	go mod tidy
	go mod verify

# ==================================================================================== #
# PRODUCTION
# ==================================================================================== #

production_host_ip = '68.183.185.70'

## production/connect: connect to the production server
.PHONY: production/connect
production/connect:
	ssh greenlight@${production_host_ip}

## production/deploy/api: deploy the cmd/api application to the server
.PHONY: prodction/deploy/api
production/deploy/api:
	rsync -P ./bin/linux_amd64/api greenlight@${production_host_ip}:~
	rsync -rP --delete ./migrations greenlight@${production_host_ip}:~
	rsync -P ./remote/production/api.service greenlight@${production_host_ip}:~
	rsync -P ./remote/production/Caddyfile greenlight@${production_host_ip}:~
	ssh -t greenlight@${production_host_ip} '\
		migrate -path ~/migrations -database $$GREENLIGHT_DB_DSN up \
		&& sudo mv ~/api.service /etc/systemd/system/ \
		&& sudo systemctl enable api \
		&& sudo systemctl restart api \
		&& sudo mv ~/Caddyfile /etc/caddy/ \
		&& sudo caddy fmt --overwrite /etc/caddy/Caddyfile \
		&& sudo systemctl reload caddy'
