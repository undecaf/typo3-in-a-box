FROM alpine:3.11

# Build command arguments
ARG BUILD_DATE
ARG COMMIT
ARG PRIMARY_TAG=exp
ARG DEPLOY_TAGS=exp
ARG TYPO3_VER=10.4

# External package versions (update as appropriate)
ARG BINDFS_VER=1.14.6
ARG S6_OVERLAY_VER=2.0.0.1

# Build _constants_ (do not change)
ARG APACHE_HOME=/var/www
ARG TYPO3_ROOT=${APACHE_HOME}/localhost
ARG TYPO3_DATADIR=/var/lib/typo3-db

# Build-time proxy settings (not persisted in the image)
ARG http_proxy
ARG https_proxy

LABEL \
    org.opencontainers.image.title="Versatile TYPO3 8.7/9.5/10.4/11.0 images" \
	org.opencontainers.image.description="TYPO3, Apache, PHP, Composer, ImageMagick; SQLite, MariaDB and PostgreSQL databases" \
	org.opencontainers.image.version="${PRIMARY_TAG}" \
	org.opencontainers.image.revision="${COMMIT}" \
	org.opencontainers.image.url="https://hub.docker.com/r/undecaf/typo3-in-a-box" \
	org.opencontainers.image.documentation="https://github.com/undecaf/typo3-in-a-box/tree/dev#typo3-in-a-box--versatile-typo3-8795104110-images" \
	org.opencontainers.image.source="https://github.com/undecaf/typo3-in-a-box" \
	org.opencontainers.image.authors="Ferdinand Kasper <fkasper@modus-operandi.at>" \
	org.opencontainers.image.created="${BUILD_DATE}"

# Independent of the TYPO3 version
COPY build-files /
RUN /usr/local/bin/build

# Depending on the TYPO3 version
COPY compose-files /
RUN /usr/local/bin/compose

# Runtime files
COPY runtime-files /
RUN /usr/local/bin/cleanup

VOLUME ${TYPO3_ROOT} ${TYPO3_DATADIR}

EXPOSE 80 443 3306 5432

# Customize the s6-overlay
ENV S6_LOGGING=2
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2

ENTRYPOINT ["/usr/local/bin/init"]
