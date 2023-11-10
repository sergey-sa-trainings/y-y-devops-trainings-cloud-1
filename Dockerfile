# Базовый образ
FROM golang:1.21 as builder

WORKDIR /go/src/catgpt
COPY ./catgpt/ .

RUN go mod download
RUN CGO_ENABLED=0 go build -o /go/bin/catgpt-app

# Финальный образ
FROM gcr.io/distroless/static-debian12:latest-amd64
COPY --from=builder /go/bin/catgpt-app /
CMD ["/catgpt-app"]
