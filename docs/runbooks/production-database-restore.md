# Production database restore

This runbook restores the ADR-018 Single-AZ production PostgreSQL database to a
new, private RDS instance and validates it without directing public traffic or
writing business data. It is for a rehearsal or an approved incident. It never
restores over the source database.

## Safety boundary

- Confirm AWS account `923300948109` and Region `eu-central-1` before every
  mutating command.
- Keep the source database deletion-protected. Restore to a new identifier in
  the production database subnet group with `publicly-accessible=false`, the
  production database security group, and encryption enabled.
- Do not read or copy secret values. ECS injects database credentials from
  Secrets Manager into short-lived migration and API tasks.
- Do not change the production API service's desired count during a rehearsal.
  Validation uses standalone tasks with course-release, projection-processing,
  and import processing disabled so no business facts are created. An incident
  traffic cutover or service suspension requires the incident commander's
  explicit approval.
- Use the latest restorable time for a normal rehearsal. An incident commander
  must approve a historical timestamp and the resulting data-loss window.
- Never delete the source database. Cleanup may delete only the exact temporary
  restore identifier after it is tagged, inspected, and no validation task is
  running.

## Targets

- Recovery point objective: at most 15 minutes.
- Recovery time objective: at most 4 hours from the recorded drill start until
  the immutable application image is database-ready against the restored copy.
- A database reaching `available` is an intermediate measurement, not complete
  recovery evidence.

## Restore procedure

1. Record the UTC drill start, source identifier, latest restorable time, source
   engine/version, encryption, public-access, deletion-protection, subnet group,
   VPC security group, backup retention, and source tags. Abort if the source is
   not private, encrypted, deletion-protected, and `available`.
2. Calculate `drill start - latest restorable time`. Abort or record an RPO
   exception if it exceeds 15 minutes.
3. Choose a unique identifier such as
   `kelimio-production-restore-drill-YYYYMMDDx`. Restore to that new identifier
   with the source DB instance class, subnet group, parameter/option groups,
   production database security group, no public access, no Multi-AZ promotion,
   encryption, and tags including `ManagedBy=restore-drill` and
   `DataClass=restore-validation`.
4. Wait for RDS `available`, record the timestamp and inspect the restored
   instance again. Do not continue if its account, Region, networking,
   encryption, engine, or tags differ from the approved values.
5. Register a temporary migration task-definition revision that changes only
   the database JDBC URL to the restore endpoint. Run one standalone migration
   task in the production API subnet and security group. Require exit code zero,
   successful TLS, validation of every Flyway migration, a current schema
   version, and successful least-privilege runtime-role reconciliation.
6. Register a temporary API task-definition revision that changes only the
   database JDBC URL and disables release projection, import, and other business
   processors. Run one standalone API task with the immutable scanned image.
   Require the application-start log, a successful Hikari connection, and ECS
   `HEALTHY`. The readiness group must include `readinessState,db`; process-only
   readiness is not recovery evidence.
7. Record the recovery timestamp and calculate the RTO from the drill start.
   Stop the standalone API task with a bounded reason. Exit code 143 after this
   explicit stop is expected; an unrequested stop is a failure.
8. Confirm the production service is still `0/0/0` and no standalone tasks are
   running or pending. Inspect the exact temporary database identifier and its
   `restore-drill` tag, then delete it with no final snapshot and delete its
   automated backups. This exception is allowed only because the target is a
   disposable copy of the still-protected source.
9. Wait until the temporary identifier no longer exists. Recheck that the
   source is `available`, private, encrypted, deletion-protected, and retains its
   backup policy. Confirm there are no remaining restore-drill databases or
   active tasks.
10. Run the production Terraform drift plan. Retain the run URL and the exact
    `No changes` result with the evidence record.

## Failure behavior

- If migration fails, preserve logs, stop all validation tasks, and do not start
  the API task.
- If API readiness does not establish a real database connection, the drill
  fails even when the process is running. Fix the release artifact through the
  normal reviewed CI/deploy path, then repeat the immutable-image validation.
- If cleanup or the source recheck fails, keep the incident open. Never weaken
  source deletion protection or network controls to make a drill pass.
- A successful same-account PITR rehearsal does not prove isolated/cross-region
  backup custody or ledger export. Those remain separate release gates.

## Evidence to retain

Retain UTC timestamps, source/target identifiers, non-secret RDS settings, RPO
and RTO calculations, migration/API task ARNs and task-definition revisions,
sanitized readiness logs, immutable image digest, CI/deploy/drift-plan links,
cleanup confirmation, source recheck, defects and remediations, and any approved
exceptions. Do not retain endpoints with credentials, secret values, tokens,
personal data, or learner content.
