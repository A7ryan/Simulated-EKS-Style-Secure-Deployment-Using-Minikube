# Dockerfile
FROM hashicorp/http-echo:latest
RUN apk update && apk add curl bash