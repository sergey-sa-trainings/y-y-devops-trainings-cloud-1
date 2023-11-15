ARG GOARCH=amd64
# Базовый образ
FROM golang:1.21 as builder

WORKDIR /go/src/catgpt
COPY ./catgpt .

RUN go mod download
RUN CGO_ENABLED=0 GOARCH=${GOARCH} go build -o /go/bin/catgpt-app

# Финальный образ
FROM gcr.io/distroless/static-debian12:latest-${GOARCH}
COPY --from=builder /go/bin/catgpt-app /
EXPOSE 8080 9090
CMD ["/catgpt-app"]
