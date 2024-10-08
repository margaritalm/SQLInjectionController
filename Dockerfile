FROM golang:1.19.1-alpine3.16 as build-env

ARG GIT_TOKEN

# Copy the source from the current directory to the Working Directory inside the container
WORKDIR /app

ENV GOPRIVATE=github.com/checkmarxDev

RUN apk add --no-cache git \
 && git config \
  --global \
  url."https://api:${GIT_TOKEN}@github.com".insteadOf \
  "https://github.com"

#Copy go mod and sum files
COPY go.mod . 
COPY go.sum .

# Get dependencies - will also be cached if we won't change mod/sum
RUN go mod download

# COPY the source code as the last step
COPY . .

# Build the Go app
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -a -installsuffix cgo -o sast-metadata cmd/sastmetadata/main.go cmd/sastmetadata/config.go

# Build the Bases migration job
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -a -installsuffix cgo -o bases-migration cmd/basesmigration/main.go cmd/basesmigration/config.go

#runtime image
FROM alpine:3.16

ARG COMMIT_SHA
ARG RELEASE_TAG

LABEL cx.commit-sha=${COMMIT_SHA}
LABEL cx.release-tag=${RELEASE_TAG}

COPY --from=build-env /app/sast-metadata /app/sast-metadata
COPY --from=build-env /app/bases-migration /app/bases-migration


COPY --from=build-env /app/api /app/api
COPY --from=build-env /app/db /app/db

ENTRYPOINT ["/app/sast-metadata"]
