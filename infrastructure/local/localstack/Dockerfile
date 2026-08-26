FROM localstack/localstack:4.14.0@sha256:3ebc37595918b8accb852f8048fef2aff047d465167edd655528065b07bc364a

COPY init/ /etc/localstack/init/ready.d/
RUN sed -i 's/\r$//' /etc/localstack/init/ready.d/*.sh \
    && chmod 0555 /etc/localstack/init/ready.d/*.sh

USER localstack
