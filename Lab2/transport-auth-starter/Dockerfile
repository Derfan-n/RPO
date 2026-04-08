FROM golang:1.26-alpine AS builder
WORKDIR /src
RUN apk add --no-cache build-base
COPY go.mod ./
RUN go mod download
COPY . .
RUN go build -o /out/transport-auth ./cmd/api

FROM alpine:3.21
WORKDIR /app
RUN apk add --no-cache nginx ca-certificates sqlite

COPY --from=builder /out/transport-auth /app/transport-auth
COPY nginx/default.conf /etc/nginx/http.d/default.conf
COPY scripts/start.sh /start.sh
COPY migrations /app/migrations
COPY certs /etc/nginx/certs
COPY docs /app/docs
COPY web /usr/share/nginx/html

RUN chmod +x /start.sh
RUN mkdir -p /run/nginx /var/lib/nginx/tmp/client_body /app/data

EXPOSE 8888
CMD ["/start.sh"]