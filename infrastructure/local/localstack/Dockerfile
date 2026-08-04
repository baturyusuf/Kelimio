FROM localstack/localstack:4.4.0@sha256:b52c16663c70b7234f217cb993a339b46686e30a1a5d9279cb5feeb2202f837c

COPY init/ /etc/localstack/init/ready.d/
RUN chmod 0555 /etc/localstack/init/ready.d/*.sh

USER localstack
