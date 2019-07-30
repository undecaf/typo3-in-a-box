FROM alpine:3.10

ARG BUILD_DATE
ARG COMMIT
ARG IMAGE_VER=experimental
ARG TYPO3_VER=10.0

LABEL \
    org.opencontainers.image.title="A multi-purpose TYPO3 8.7/9.5/10.0 image" \
	org.opencontainers.image.description="TYPO3, Apache, PHP, Composer, ImageMagick; SQLite, MariaDB and PostgreSQL databases" \
	org.opencontainers.image.version="${IMAGE_VER}" \
	org.opencontainers.image.revision="${COMMIT}" \
	org.opencontainers.image.url="https://hub.docker.com/r/undecaf/typo3-in-a-box" \
	org.opencontainers.image.documentation="https://github.com/undecaf/typo3-in-a-box#typo3-in-a-box--a-multi-purpose-typo3-8795100-image" \
	org.opencontainers.image.source="https://github.com/undecaf/typo3-in-a-box" \
	org.opencontainers.image.authors="Ferdinand Kasper <fkasper@modus-operandi.at>" \
	org.opencontainers.image.created="${BUILD_DATE}"

COPY files /
RUN /usr/local/bin/build

VOLUME /var/www/localhost /var/lib/typo3-db

EXPOSE 80 3306 5432

ENTRYPOINT ["/usr/local/bin/init"]
CMD ["httpd", "-D", "FOREGROUND"]
STOPSIGNAL SIGHUP
