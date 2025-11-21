FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY main.go .
RUN go build -o collector main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/collector .

# Create data directory
RUN mkdir -p /data/raw

CMD ["./collector"]
