# syntax=docker/dockerfile:1

# The Spring Boot JAR is architecture-independent. Compile it on BuildKit's
# native worker platform and reserve ARM64 emulation/cross-pull for the runtime
# image, otherwise production builds can spend many minutes running Gradle
# under QEMU.
FROM --platform=$BUILDPLATFORM gradle:8.14.3-jdk21@sha256:21bd311ed01360c189b8870c6b6e988199ff10f72d445d02fb39d3cff9da91d7 AS build
WORKDIR /workspace
COPY settings.gradle.kts build.gradle.kts gradle.properties gradle.lockfile ./
COPY src ./src
RUN gradle --no-daemon clean bootJar

FROM eclipse-temurin:21-jre-alpine@sha256:3f08b13888f595cc49edabea7250ba69499ba25602b267da591720769400e08c AS runtime
RUN apk add --no-cache --upgrade \
        libexpat=2.8.3-r0 \
        libcrypto3=3.5.8-r0 \
        libssl3=3.5.8-r0 \
        openssl=3.5.8-r0 \
        p11-kit=0.26.2-r0 \
        p11-kit-trust=0.26.2-r0 \
        sqlite-libs=3.53.4-r0 \
    && addgroup -S kelimio \
    && adduser -S kelimio -G kelimio \
    && chown kelimio:kelimio /tmp \
    && chmod 0700 /tmp
WORKDIR /app
ARG AWS_RDS_GLOBAL_BUNDLE_SHA256=e5bb2084ccf45087bda1c9bffdea0eb15ee67f0b91646106e466714f9de3c7e3
RUN wget -q https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem -O /app/rds-global-bundle.pem \
    && echo "${AWS_RDS_GLOBAL_BUNDLE_SHA256}  /app/rds-global-bundle.pem" | sha256sum -c - \
    && chmod 0444 /app/rds-global-bundle.pem
COPY --from=build /workspace/build/libs/kelimio-api-*.jar /app/kelimio-api.jar
# Fargate bind volumes otherwise default to root:root/0755. Declaring the same
# path as a Docker volume tells the ECS data plane to copy the image ownership
# and mode, keeping the root filesystem read-only while Tomcat can create its
# private temporary directory as the unprivileged kelimio user.
VOLUME ["/tmp"]
USER kelimio
EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "/app/kelimio-api.jar"]
