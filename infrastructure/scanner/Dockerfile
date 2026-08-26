# syntax=docker/dockerfile:1
FROM clamav/clamav:1.4.5@sha256:e7ead98e7e07231b151bce988e0cfb0a3b46e6e7046d9dd44fd838c0df724a03

COPY infrastructure/local/clamav/healthcheck.sh /usr/local/bin/kelimio-clamav-healthcheck
RUN sed -i 's/\r$//' /usr/local/bin/kelimio-clamav-healthcheck \
    && chmod 0555 /usr/local/bin/kelimio-clamav-healthcheck
