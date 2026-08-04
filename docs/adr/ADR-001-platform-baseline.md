# ADR-001: Production Platform and Version Baseline

- Status: Accepted
- Date: 2026-07-21
- Partially superseded by: ADR-018 for the initial production-only,
  cost-guarded AWS deployment topology

## Context

The architecture PDFs compare Flutter, React Native, native mobile, and Kotlin Multiplatform, and present AWS, GCP, and Azure as viable managed-cloud choices. The production master prompt makes a narrower default choice. The current upstream Spring ecosystem also includes a Boot 4 line, while the master explicitly requires a stable Spring Boot 3.x backend on Java 21.

Implementation is now beginning, so platform ambiguity would create incompatible scaffolds, duplicated clients, and migration cost.

## Decision

### Mobile

Use one Flutter codebase for Android and iOS:

- Flutter 3.44.0 and bundled Dart 3.12 line;
- Material 3, Riverpod, `go_router`, Drift/SQLite, Dio, and OpenAPI-generated client;
- Android target/compile API 36 with minimum API 24;
- iOS deployment target 15.0;
- explicit adapters around billing, ads, push, integrity, secure storage, file access, and deep links.

React Native, separate native applications, and KMP are not parallel deliverables. Reconsideration requires a superseding ADR with team capacity, migration, feature parity, plugin/native surface, release cost, and rollback analysis.

### Backend

Use Kotlin 2.4.10 on Java 21 with Spring Boot 3.5.16, Gradle 8.14.3 Kotlin DSL, imperative Spring MVC/transaction semantics, PostgreSQL, jOOQ/Flyway, Redis/Lettuce, and separate API/worker entry points from one modular-monolith codebase.

Boot 4 is deferred. It may be proposed only with the compatibility and migration evidence listed in `docs/VERSIONS.md`.

### Web

Use Node.js 24 LTS and an exactly locked stable patch from the Next.js 16.2 line. Internal admin and public/legal surfaces are separate applications but may share deliberate contract/design packages.

### Cloud

AWS is the default production platform:

- ECS Fargate API and worker services behind ALB;
- CloudFront and WAF where public delivery requires them;
- RDS PostgreSQL Multi-AZ or Aurora PostgreSQL chosen by measured cost/load;
- ElastiCache Redis;
- S3 for Excel, media, offline packages, and reports;
- SQS with DLQ for work delivery; EventBridge only for schedules/routing, not as an undifferentiated queue;
- Cognito with custom domain or another owner-approved managed OIDC provider;
- SES, KMS, Secrets Manager, ECR, Route 53/ACM, CloudWatch/CloudTrail, and OpenTelemetry;
- Terraform 1.15.8 and GitHub Actions OIDC short-lived deployment roles.

Start in one primary region with Multi-AZ managed services. A disaster-recovery region may hold backups and recovery infrastructure as policy requires; multi-region active-active writes are not an initial feature.

## Deferred alternatives and adoption gates

- Do not add Kubernetes, service mesh, Kafka, OpenSearch, service-per-domain databases, or global distributed SQL in the initial system.
- Redis is wired behind clear interfaces but used only for proven cache, rate-limit, and live-ranking cases; PostgreSQL remains truth.
- PostgreSQL full-text/trigram search is the starting search implementation. OpenSearch needs measured relevance, index size, or latency evidence and an owned reindex/replay plan.
- Service extraction needs independent ownership/deploy/scale requirements, SRE/on-call capacity, contract/data ownership, and business value greater than distributed-system cost.

## Consequences

- The repository has one build direction and one production-cloud reference.
- The team accepts Flutter/native-adapter ownership and JVM container tuning in exchange for single-team delivery and strong transaction tooling.
- Version pins are deliberate constraints, not a claim that newer upstream majors do not exist.
- Cloud-portable concepts remain at boundaries, but code may use valuable AWS managed features rather than targeting a lowest common denominator.
