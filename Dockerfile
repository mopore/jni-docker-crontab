# Multi-arch build: fetch dasel (yaml/toml->json) per arch
FROM --platform=$BUILDPLATFORM alpine:3.20 AS dasel-build
ARG TARGETARCH
ARG DASEL_VERSION=2.5.0
WORKDIR /root/
RUN apk --no-cache add wget ca-certificates gzip \
 && case "$TARGETARCH" in amd64) DASEL_ARCH="amd64";; arm64) DASEL_ARCH="arm64";; arm) DASEL_ARCH="armv7";; *) echo "Unsupported arch $TARGETARCH"; exit 1;; esac \
 && wget -q https://github.com/TomWright/dasel/releases/download/v${DASEL_VERSION}/dasel_linux_${DASEL_ARCH}.gz \
 && gunzip dasel_linux_${DASEL_ARCH}.gz \
 && mv dasel_linux_${DASEL_ARCH} dasel \
 && chmod +x dasel

FROM docker:29-cli
ENV HOME_DIR=/opt/crontab
COPY --from=dasel-build /root/dasel /usr/local/bin/dasel
RUN apk add --no-cache --virtual .run-deps gettext jq bash tini \
 && mkdir -p ${HOME_DIR}/jobs ${HOME_DIR}/projects \
 && adduser -S docker -D
COPY docker-entrypoint /
ENTRYPOINT ["/sbin/tini", "--", "/docker-entrypoint"]
HEALTHCHECK --interval=5s --timeout=3s CMD ps aux | grep '[c]rond' || exit 1
CMD ["crond", "-f", "-d", "6", "-c", "/etc/crontabs"]
