# The Go binary is cross-compiled on the build host (no QEMU); the final stage only copies files,
# so any base image that has both linux/amd64 and linux/arm64 works.
ARG BASE_IMAGE=registry.suse.com/bci/bci-micro:16.0

FROM --platform=$BUILDPLATFORM registry.suse.com/bci/golang:1.26 AS build
ARG TARGETOS
ARG TARGETARCH
ARG VERSION=dev
WORKDIR /src
COPY go.mod main.go ./
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags "-s -w -X main.version=${VERSION}" -o /out/nv-cicd-demo .

FROM ${BASE_IMAGE}
COPY --from=build /out/nv-cicd-demo /usr/local/bin/nv-cicd-demo
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/nv-cicd-demo"]
