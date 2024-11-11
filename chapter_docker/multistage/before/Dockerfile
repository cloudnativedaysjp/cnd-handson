FROM golang:latest

WORKDIR /app
COPY ./app /app
RUN go mod init server \
        && go mod tidy \
        && go build -o server server.go
EXPOSE 1323
CMD [ "/app/server" ]
