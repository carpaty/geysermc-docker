# syntax=docker/dockerfile:1

FROM alpine:3.22 AS downloader

ARG GEYSER_DOWNLOAD_URL="https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/standalone"
ARG GEYSER_SHA256=""

RUN apk add --no-cache ca-certificates curl \
    && curl --fail --location --retry 5 --retry-all-errors \
        --output /tmp/geyser.jar "${GEYSER_DOWNLOAD_URL}" \
    && if [ -n "${GEYSER_SHA256}" ]; then \
        echo "${GEYSER_SHA256}  /tmp/geyser.jar" | sha256sum -c -; \
    fi

FROM eclipse-temurin:21-jre-alpine

ARG BUILD_DATE=""
ARG VCS_REF=""

LABEL org.opencontainers.image.title="Geyser Standalone" \
      org.opencontainers.image.description="GeyserMC standalone proxy for Minecraft Bedrock and Java Edition" \
      org.opencontainers.image.source="https://github.com/carpaty/geysermc-docker" \
      org.opencontainers.image.url="https://geysermc.org/" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}"

RUN apk add --no-cache ca-certificates curl \
    && addgroup -g 1000 geyser \
    && adduser -D -H -u 1000 -G geyser geyser \
    && mkdir -p /opt/geyser /data \
    && chown geyser:geyser /data

COPY --from=downloader --chown=root:root /tmp/geyser.jar /opt/geyser/geyser.jar
COPY --chown=root:root docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod 0555 /usr/local/bin/docker-entrypoint.sh \
    && chmod 0444 /opt/geyser/geyser.jar

USER geyser:geyser
WORKDIR /data

ENV HOME="/data" \
    GEYSER_DOWNLOAD_URL="https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/standalone" \
    GEYSER_SYNC="false" \
    JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0 -XX:+UseG1GC"

VOLUME ["/data"]
EXPOSE 19132/udp

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["--nogui"]
