FROM alpine:3.10

ARG BUILD_DATE
ARG COMMIT
ARG IMAGE_VER=experimental
ARG TYPO3_VER=10.0

LABEL \
    org.opencontainers.image.title="A ready-to-run TYPO3 8.7/9.5/10.0 image" \
	org.opencontainers.image.description="TYPO3, Apache, PHP, Composer, ImageMagick; SQLite, MariaDB and PostgreSQL databases to choose from" \
	org.opencontainers.image.version="${IMAGE_VER}" \
	org.opencontainers.image.revision="${COMMIT}" \
	org.opencontainers.image.url="https://hub.docker.com/r/undecaf/typo3-dev" \
	org.opencontainers.image.documentation="https://github.com/undecaf/typo3-dev#containerized-typo3--from-quick-start-to-extension-development" \
	org.opencontainers.image.source="https://github.com/undecaf/typo3-dev" \
	org.opencontainers.image.authors="Ferdinand Kasper <fkasper@modus-operandi.at>" \
	org.opencontainers.image.created="${BUILD_DATE}"

COPY files /
RUN /usr/local/bin/build

VOLUME /var/www/localhost /var/lib/mysql /var/lib/postgresql/data

EXPOSE 80 3306 5432

ENTRYPOINT ["/usr/local/bin/init"]
CMD ["httpd", "-D", "FOREGROUND"]
STOPSIGNAL SIGHUP
