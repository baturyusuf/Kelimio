# syntax=docker/dockerfile:1

# The Spring Boot JAR is architecture-independent. Compile it on BuildKit's
# native worker platform and reserve ARM64 emulation/cross-pull for the runtime
# image, otherwise production builds can spend many minutes running Gradle
# under QEMU.
FROM --platform=$BUILDPLATFORM gradle:9.6.0-jdk21@sha256:6b71d4d40e45200709c178ca0ab10125e1d99e6e44dec6bcbabd0a3371f8e650 AS build
WORKDIR /workspace
COPY settings.gradle.kts build.gradle.kts gradle.properties gradle.lockfile ./
COPY src ./src
RUN gradle --no-daemon clean bootJar

FROM eclipse-temurin:21-jre-alpine@sha256:3f08b13888f595cc49edabea7250ba69499ba25602b267da591720769400e08c AS runtime
RUN apk add --no-cache --upgrade \
        libexpat=2.8.2-r0 \
        p11-kit=0.26.2-r0 \
        p11-kit-trust=0.26.2-r0 \
    && addgroup -S kelimio \
    && adduser -S kelimio -G kelimio
WORKDIR /app
ARG AWS_RDS_GLOBAL_BUNDLE_SHA256=e5bb2084ccf45087bda1c9bffdea0eb15ee67f0b91646106e466714f9de3c7e3
RUN wget -q https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem -O /app/rds-global-bundle.pem \
    && echo "${AWS_RDS_GLOBAL_BUNDLE_SHA256}  /app/rds-global-bundle.pem" | sha256sum -c - \
    && chmod 0444 /app/rds-global-bundle.pem
COPY --from=build /workspace/build/libs/kelimio-api-*.jar /app/kelimio-api.jar
USER kelimio
EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "/app/kelimio-api.jar"]
