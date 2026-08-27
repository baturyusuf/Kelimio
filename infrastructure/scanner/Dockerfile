# syntax=docker/dockerfile:1
# Prepare the pinned image at build time so the production task can run as the
# unprivileged clamav user with every Linux capability dropped by ECS/Fargate.
FROM clamav/clamav:1.4.5@sha256:e7ead98e7e07231b151bce988e0cfb0a3b46e6e7046d9dd44fd838c0df724a03

RUN apk add --no-cache --upgrade \
        libcrypto3=3.5.8-r0 \
        libssl3=3.5.8-r0

COPY infrastructure/local/clamav/healthcheck.sh /usr/local/bin/kelimio-clamav-healthcheck
COPY infrastructure/scanner/entrypoint.sh /usr/local/bin/kelimio-clamav-entrypoint
RUN sed -i 's/\r$//' /usr/local/bin/kelimio-clamav-healthcheck \
    && sed -i 's/\r$//' /usr/local/bin/kelimio-clamav-entrypoint \
    && chmod 0555 /usr/local/bin/kelimio-clamav-healthcheck \
        /usr/local/bin/kelimio-clamav-entrypoint \
    && install -d -o clamav -g clamav -m 0775 /run/clamav \
    && chown -R clamav:clamav /var/lib/clamav

USER clamav
ENTRYPOINT ["/usr/local/bin/kelimio-clamav-entrypoint"]
