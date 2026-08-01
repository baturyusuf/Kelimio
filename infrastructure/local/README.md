# Local services

The root `compose.yaml` runs real local infrastructure rather than application
fakes: PostgreSQL, Redis, LocalStack S3/SQS/EventBridge, Keycloak, Mailpit,
ClamAV, and an OpenTelemetry Collector.

Local credentials in the Compose defaults are intentionally low-value and must
never be reused outside a developer workstation. No production or staging
secret belongs in this directory.

```powershell
docker compose up -d
docker compose --profile app up --build
```

Keycloak starts without demo users. Register a real local user through the OIDC
registration flow. Realm imports require email verification and deliver the
message to Mailpit at `http://localhost:8025`. The one-shot `keycloak-config`
service also reconciles these non-secret local realm settings after Keycloak is
healthy, so an existing development volume receives them without deleting its
users. After verification, the app requires explicit profile/language/time-zone
setup. The stack does not seed fake users or learning results. An explicitly
enabled local-only API command can install the immutable reviewed Type-A starter
course; it is not the production Excel-import path.

External images and the LocalStack base are digest-pinned. LocalStack runs as
its packaged non-root user. Updating a tag requires refreshing and reviewing
the matching digest; do not remove the digest to make an upgrade appear easier.

The default issuer is `http://localhost:8081/realms/kelimio`. For an Android
emulator or attached device, prefer `adb reverse tcp:8081 tcp:8081` and
`adb reverse tcp:8080 tcp:8080` so the default remains valid. For a LAN device,
set both `KELIMIO_LOCAL_KEYCLOAK_BASE_URL` and `KELIMIO_LOCAL_OIDC_ISSUER` to
the same reachable host before creating the stack; tokens and API validation
must use the exact same issuer.
