# transport-auth starter

Starter project for the lab: Go + SQLite + JWT + CRUD + goose + Swagger + Nginx + HTTPS + Docker.

## Quick start

```bash
cp .env.example .env
mkdir -p data certs
mkcert -cert-file certs/localhost.pem -key-file certs/localhost-key.pem localhost 127.0.0.1 ::1

go mod tidy
goose -dir migrations sqlite3 ./data/app.db up
go run ./cmd/api
```

Health check:
- http://localhost:8080/health

Swagger after generation:
```bash
swag init -g cmd/api/main.go
```
- http://localhost:8080/api/v1/swagger/index.html

## Docker

```bash
docker compose up --build
```

Main URL through Nginx/TLS:
- https://localhost:8888/api/v1/health
- https://localhost:8888/api/v1/swagger/index.html
