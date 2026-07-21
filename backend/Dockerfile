FROM gradle:8.14.3-jdk21@sha256:21bd311ed01360c189b8870c6b6e988199ff10f72d445d02fb39d3cff9da91d7 AS build
WORKDIR /workspace
COPY settings.gradle.kts build.gradle.kts gradle.properties gradle.lockfile ./
COPY src ./src
RUN gradle --no-daemon clean bootJar

FROM eclipse-temurin:21-jre-alpine@sha256:3f08b13888f595cc49edabea7250ba69499ba25602b267da591720769400e08c AS runtime
RUN addgroup -S kelimio && adduser -S kelimio -G kelimio
WORKDIR /app
COPY --from=build /workspace/build/libs/kelimio-api-*.jar /app/kelimio-api.jar
USER kelimio
EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "/app/kelimio-api.jar"]
