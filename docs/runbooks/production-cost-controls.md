# Production cost controls

This runbook governs the ADR-018 production-only AWS environment in account
`923300948109` and Region `eu-central-1`.

## Objective and limits

- The normal monthly operating target is USD 30-35.
- AWS Budgets is configured at USD 50 per calendar month.
- Cost and usage data is delayed. The controls below reduce exposure; they are
  not a hard billing cap and a small overrun remains possible.
- Automation may restrict traffic and stop explicitly registered stateless EC2
  instances or RDS databases. It must never delete PostgreSQL data, backups,
  audit facts, course releases, import archives, queues, or cryptographic keys.

## Automatic modes

| Actual monthly spend | Mode | Service behavior |
| --- | --- | --- |
| Below 70% | `NORMAL` | All configured capabilities are available. |
| 70% or above | `CONSERVE` | Expensive imports, authoring and publication operations return a retryable `503`. Learning remains available. |
| 80% or above | `READ_ONLY` | Unsafe API methods return a retryable `503`; reads remain available. |
| 90% or above | `SUSPENDED` | Versioned API traffic returns a retryable `503`; explicitly registered compute/database resources may be stopped. |

Every transition publishes an operations notification and writes the selected
mode to `/kelimio/production/operating-mode` in Systems Manager Parameter Store.
The API caches the value briefly. In production it fails closed to `SUSPENDED`
when no trustworthy current or bounded last-known value is available.

The budget also sends an operations-only actual-spend alert at 50% and a
forecast alert at 70%. The notification email subscription is not active until
the owner confirms the AWS email.

## Deployment checks

Before public traffic:

1. Confirm the budget notification subscription and protected GitHub
   `production` environment.
2. Confirm the cost-controller Lambda functions can write only the production
   operating-mode parameter and can stop only resources tagged
   `Project=kelimio`, `Environment=production`, and `AutoSuspend=true` whose IDs
   are explicitly supplied by Terraform.
3. Exercise all four modes against the no-public-traffic production canary and
   verify localized Android messages.
4. Confirm that durable storage and backup resources are absent from every stop
   or deletion permission.
5. Record the budget, alarm, Lambda, Parameter Store and CloudTrail evidence in
   the release evidence bundle.

## Responding to a cost transition

1. Treat the notification as an incident and inspect Cost Explorer by service,
   usage type and tag. Do not place credentials or billing exports in chat,
   source control or application logs.
2. Check CloudTrail for the budget notification, Lambda invocation and parameter
   update. Confirm the active parameter value.
3. If the increase is expected, keep the automatically selected mode until the
   owner explicitly approves restoration. If it is unexpected, preserve logs,
   revoke the affected runtime path, and keep the stricter mode active.
4. Restore database and compute only after the cause is understood and the
   projected month-end spend is acceptable. RDS restart and API recovery must be
   followed by health, migration, outbox-lag and immutable-release checks.
5. Change the operating mode back toward `NORMAL` one step at a time and run a
   smoke test after each change. Record who approved the change and why.

At the start of a new billing month, AWS Budgets does not automatically prove
that the incident is resolved. An operator must review spend and deliberately
restore service.

## Manual emergency control

An authorized operator may set the production parameter to a stricter mode at
any time. Moving to a less restrictive mode requires an incident record and
owner approval. Manual database stop/start must use the documented resource ID;
never disable deletion protection or shorten backup/import retention as a cost
response.
