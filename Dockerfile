FROM alpine:3.11

# Build arguments
ARG BUILD_DATE
ARG COMMIT
ARG PRIMARY_TAG=exp
ARG DEPLOY_TAGS=exp
ARG TYPO3_VER=10.0

# Build _constants_
ARG APACHE_HOME=/var/www
ARG TYPO3_ROOT=${APACHE_HOME}/localhost
ARG TYPO3_DATADIR=/var/lib/typo3-db

LABEL \
    org.opencontainers.image.title="A versatile TYPO3 8.7/9.5/10.2 image" \
	org.opencontainers.image.description="TYPO3, Apache, PHP, Composer, ImageMagick; SQLite, MariaDB and PostgreSQL databases" \
	org.opencontainers.image.version="${PRIMARY_TAG}" \
	org.opencontainers.image.revision="${COMMIT}" \
	org.opencontainers.image.url="https://hub.docker.com/r/undecaf/typo3-in-a-box" \
	org.opencontainers.image.documentation="https://github.com/undecaf/typo3-in-a-box/#typo3-in-a-box--a-versatile-typo3-8795102-image" \
	org.opencontainers.image.source="https://github.com/undecaf/typo3-in-a-box" \
	org.opencontainers.image.authors="Ferdinand Kasper <fkasper@modus-operandi.at>" \
	org.opencontainers.image.created="${BUILD_DATE}"

# Independent of the TYPO3 version
COPY build-files /
RUN /usr/local/bin/build

# Depends on the TYPO3 version
COPY compose-files /
RUN /usr/local/bin/compose

# Runtime files
COPY runtime-files /
RUN chmod -R 755 /usr/local/bin

VOLUME ${TYPO3_ROOT} ${TYPO3_DATADIR}

EXPOSE 80 443 3306 5432 514/udp

ENTRYPOINT ["/usr/local/bin/init"]
CMD ["httpd", "-D", "FOREGROUND"]
STOPSIGNAL SIGHUP
