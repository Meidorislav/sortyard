# ── dev: hot reload via air ──────────────────────────────────────────────────
FROM golang:1.22-alpine AS dev
RUN go install github.com/air-verse/air@latest
WORKDIR /app
EXPOSE 8080
CMD ["air"]

# ── builder ──────────────────────────────────────────────────────────────────
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /server ./cmd/server

# ── prod: minimal image ───────────────────────────────────────────────────────
FROM alpine:3.19 AS prod
RUN apk add --no-cache ca-certificates tzdata
WORKDIR /app
COPY --from=builder /server .
EXPOSE 8080
CMD ["./server"]
