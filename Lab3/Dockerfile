FROM golang:1.26-alpine AS backend-builder
WORKDIR /src
RUN apk add --no-cache build-base
COPY go.mod ./
COPY go.sum ./
RUN go mod download
COPY . .
RUN go build -o /out/transport-auth ./cmd/api

FROM node:22-alpine AS frontend-builder
WORKDIR /frontend
COPY frontend/package.json ./
RUN npm install
COPY frontend .
RUN npm run build

FROM alpine:3.21
WORKDIR /app
RUN apk add --no-cache nginx ca-certificates sqlite

COPY --from=backend-builder /out/transport-auth /app/transport-auth
COPY --from=frontend-builder /frontend/dist /usr/share/nginx/html
COPY nginx/default.conf /etc/nginx/http.d/default.conf
COPY scripts/start.sh /start.sh
COPY migrations /app/migrations
COPY certs /etc/nginx/certs
COPY docs /app/docs

RUN chmod +x /start.sh
RUN mkdir -p /run/nginx /var/lib/nginx/tmp/client_body /app/data

EXPOSE 8888
CMD ["/start.sh"]
