# Build
# 
FROM golang:1.23.1 AS stage

WORKDIR /app
COPY ./app /app
RUN go mod init server \
        && go mod tidy \
        && go build -o server server.go

# 
# Deploy
# 
FROM gcr.io/distroless/base-debian11

WORKDIR /app
COPY --from=stage /app/server /app/server
USER nonroot:nonroot
EXPOSE 1323
CMD [ "/app/server" ]
