# Production database restore evidence — 2026-08-04

Status: **PASSED FOR SAME-ACCOUNT PITR AND IMMUTABLE-APPLICATION RECOVERY; NOT PUBLIC OR PUBLISH-READY**

## Scope

This record covers an isolated point-in-time restore of
`kelimio-production-postgres` in AWS account `923300948109`, Region
`eu-central-1`. No public traffic was enabled, the production ECS service stayed
at desired/running/pending `0/0/0`, and no production business data was written.
The restored copy was deleted after validation. This evidence satisfies the
same-account PITR restore exercise but not isolated/cross-region backup custody,
ledger export, or the remaining launch gates.

Validated source revision: `fb2e4ea9513b36f92ec1c4caf0fe59bdb98b5a01`

Validated image digest:
`sha256:20610a01b7273aa10f01829e1ea21cd66f1d6594c181355c895d6a3c5324e291`

## Measured objectives

| Measurement | Observation | Target | Result |
| --- | --- | --- | --- |
| Drill start | `2026-08-04T15:58:43.9264455Z` | Recorded before mutation | Pass |
| Source latest restorable time | `2026-08-04T15:53:38Z` | — | — |
| RPO lag | 5 minutes 5.926 seconds | At most 15 minutes | Pass |
| Restore request accepted | `2026-08-04T15:58:57.2390742Z` | — | — |
| Restored database available | `2026-08-04T16:10:13.6453410Z` | Intermediate only | 11 minutes 29.719 seconds |
| Immutable application database-ready | `2026-08-04T17:04:25.8968878Z` | At most 4 hours from drill start | Pass: 1 hour 5 minutes 41.970 seconds |

The RTO includes discovery, correction, CI, immutable redeployment, and final
revalidation of two release defects; it is not limited to the RDS control-plane
availability time.

## Restore and schema validation

- Temporary target: `kelimio-production-restore-drill-20260804a`.
- The target was PostgreSQL 17.5 on `db.t4g.micro`, private, encrypted, and in
  the production private DB subnet group and database security group. Deletion
  protection was disabled only on this tagged disposable restore to allow
  cleanup; source deletion protection remained enabled.
- Migration task
  `arn:aws:ecs:eu-central-1:923300948109:task/kelimio-production-cluster/4d5286f27d584ee4af94582b1abe05bc`
  used migration task definition revision 4. It connected with TLS, validated
  all 13 migrations, found schema version 13 current, reconciled the
  least-privilege `kelimio_runtime` role, and exited zero.

## Defects found and corrected

1. The first API validation exposed that the read-only-root Fargate task's ECS
   bind volume mounted `/tmp` as root-owned, preventing non-root Tomcat startup.
   [PR 35](https://github.com/baturyusuf/Kelimio/pull/35) makes `/tmp` a
   Dockerfile-owned volume for `kelimio:kelimio` mode `0700` and adds a CI smoke
   test for the same read-only-root/named-volume runtime. Backend CI run
   [30928693931](https://github.com/baturyusuf/Kelimio/actions/runs/30928693931),
   security run
   [30928696071](https://github.com/baturyusuf/Kelimio/actions/runs/30928696071),
   and inactive deploy run
   [30929095124](https://github.com/baturyusuf/Kelimio/actions/runs/30929095124)
   passed.
2. The next task reached process readiness without proving a database
   connection because the readiness group did not include the database health
   contributor. [PR 36](https://github.com/baturyusuf/Kelimio/pull/36) requires
   `readinessState,db` and adds a configuration regression test. Backend CI run
   [30930700525](https://github.com/baturyusuf/Kelimio/actions/runs/30930700525),
   security run
   [30930701812](https://github.com/baturyusuf/Kelimio/actions/runs/30930701812),
   and final inactive deploy run
   [30931238662](https://github.com/baturyusuf/Kelimio/actions/runs/30931238662)
   passed. The final run retained scan/SBOM gates and produced API task
   definition revision 6 at the validated digest.

## Final application validation

- Standalone task:
  `arn:aws:ecs:eu-central-1:923300948109:task/kelimio-production-cluster/497568799ef6487394a067163559d5a2`.
- Requested at `2026-08-04T17:01:37.7410271Z`; application start completed at
  `2026-08-04T17:03:36.929Z`; the Hikari pool completed its restored-database
  connection at `2026-08-04T17:03:47.442Z`; ECS reported database-aware
  `HEALTHY` at `2026-08-04T17:04:25.8968878Z`.
- The task was explicitly stopped after validation with reason
  `Final restore readiness verified; cleanup requested`; it stopped at
  `2026-08-04T17:05:03.110Z` with expected exit code 143.
- Course-release projection, import processing, and other business processors
  were disabled for the standalone validation task. The public service was not
  activated.

## Cleanup and retained state

- Before cleanup there were zero running/pending standalone tasks and the
  production service remained `0/0/0`.
- The exact tagged target `kelimio-production-restore-drill-20260804a` was
  deleted with its disposable automated backups. A post-delete inventory found
  no restore-drill database.
- The source `kelimio-production-postgres` remained `available`, private,
  encrypted, deletion-protected, and configured for seven-day retention. No ECS
  task remained active.
- [Final production Terraform plan run 30932618870](https://github.com/baturyusuf/Kelimio/actions/runs/30932618870)
  completed successfully against source revision
  `fb2e4ea9513b36f92ec1c4caf0fe59bdb98b5a01` and reported
  `No changes. Your infrastructure matches the configuration.`

## Gates intentionally left open

- LB-014 remains open for approved isolated/cross-region backup custody, ledger
  export, retention/legal-hold policy, incident ownership, and combined recovery
  evidence.
- Google identity, SES production sending, custom DNS/TLS edge and WAF,
  production import worker/private scanning, key rotation/rollback, independent
  GitHub approval, provider/legal/store configuration, and the full pre-traffic
  canary remain release blockers.

No credential, token, secret value, endpoint password, notification address,
personal data, or learner content is included in this evidence.
