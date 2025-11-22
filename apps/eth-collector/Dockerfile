FROM golang:1.23-alpine AS builder

WORKDIR /app
COPY go.mod main.go ./
RUN go mod tidy && go mod download
RUN go build -o collector main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/collector .


RUN mkdir -p /data/raw

CMD ["./collector"]
