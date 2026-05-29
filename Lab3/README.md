# transport-auth starter

Starter project for the lab: Go + SQLite + JWT + CRUD + goose + Swagger + Nginx + HTTPS + Docker.

## Что изменено

- старый статический фронтенд на HTML/JS удалён;
- добавлен новый фронтенд на **React + Vite**;
- Docker собирает backend и frontend в одном образе;
- Nginx раздаёт React SPA и проксирует REST API по HTTPS.

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

## Frontend

Локальный запуск React-фронтенда:

```bash
cd frontend
npm install
npm run dev
```

Vite dev server по умолчанию запускается на:
- http://localhost:5173

## Docker

```bash
docker compose up --build
```

Main URLs through Nginx/TLS:
- https://localhost:8888/
- https://localhost:8888/api/v1/health
- https://localhost:8888/api/v1/swagger/index.html

## Тестовые пользователи

- admin / admin123
- user / user123
