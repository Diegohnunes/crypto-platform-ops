# Build Stage
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o collector main.go

# Runtime Stage
FROM alpine:3.18
WORKDIR /app
COPY --from=builder /app/collector .
EXPOSE 8080
CMD ["./collector"]
