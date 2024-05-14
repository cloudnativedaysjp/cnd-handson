FROM golang:1.19.3 AS stage

WORKDIR /app
COPY ./app /app
RUN go mod init server \
        && go mod tidy \
        && go build -o server server.go
