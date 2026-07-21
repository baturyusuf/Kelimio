# Launch Blockers

Current decision: **BLOCKED — NOT PUBLISH-READY**

This register contains conditions that prevent a production release. A row closes only when objective evidence is linked from the Evidence column and the release owner accepts it. Development may proceed around an external dependency, but a provider-dependent feature may not be faked or silently disabled in production.

| ID | Blocking condition | Required resolution/evidence | Status |
| --- | --- | --- | :---: |
| LB-001 | A complete reproducible cross-platform product runtime does not exist. | Run the Docker-backed stack and migrations, native Android/iOS builds, both web deployments, CI, and infrastructure from clean supported hosts with retained evidence. | Open |
| LB-002 | The auth-to-answer code slice lacks real staging acceptance. | Staging E2E evidence for real registration/sign-in, course access, answer submission, backend score/energy transaction, idempotent retry, outbox projection, and mobile display. | Open |
| LB-003 | Owner P0 product/legal/platform decisions are unresolved. | Relevant rows in `docs/OWNER_ACTIONS.md` are approved and recorded in contracts/ADRs where needed. | Open |
| LB-004 | Identity and account lifecycle are not production-integrated. | Managed OIDC, recovery, multi-device refresh rotation, export, deletion, and audited support behavior pass integration/security tests. | Open |
| LB-005 | Safe Excel import and mobile authoring are absent. | Malicious-fixture tests, deterministic planner tests, immutable archive, idempotent commit, conflict UI, release publication, rollback, and reprojection evidence. | Open |
| LB-006 | Online learning integrity is unproven. | Property/integration/E2E evidence for scoring, energy, completion, revision pinning, duplicate/replay behavior, lifetime monotonicity, fraud projection, and no answer key in online clients. | Open |
| LB-007 | Offline-package isolation is unproven. | Signature/hash, authorization, atomic install, entitlement lock, version check, and proof that answer history cannot reach scored APIs. | Open |
| LB-008 | Store commerce and entitlement lifecycle are not operational. | Course-specific products active in both stores; sandbox then production verification, restore, RTDN/ASSN V2, refund/void/chargeback, reconciliation, and revocation tests. | Open |
| LB-009 | Rewarded advertising is not production-verified. | AdMob SSV signature verification, replay protection, consent/ATT policy, delayed callback behavior, abuse controls, and production ad-unit configuration. | Open |
| LB-010 | Marketplace earnings, KYC/KYB, tax, and payout are unresolved. | Real provider integration, append-only earnings/reversal ledger, financial reconciliation, holds/review, provider webhook tests, and approved marketplace/legal policy. | Open |
| LB-011 | UGC, public profile, privacy, child safety, and moderation controls are incomplete. | Approved policies plus reporting, blocking, review, appeal, takedown, scraping/rate limits, privacy requests, and audited admin workflows. | Open |
| LB-012 | Production AWS environments and secure CI/CD do not exist. | Terraform evidence for isolated environments, TLS/WAF, managed data/queue/storage, KMS/secrets, OIDC deployment roles, protected approvals, canary/staged release, and rollback. | Open |
| LB-013 | Observability, incident response, and operational ownership are absent. | Critical-path SLO dashboards, alerts, trace/log/metric correlation, redaction evidence, runbooks, escalation owners, and an incident exercise. | Open |
| LB-014 | Backup and disaster recovery are unproven. | PITR/backup policy, isolated copy, ledger export, documented restore test, and measured RPO no worse than 15 minutes/RTO no worse than 4 hours. | Open |
| LB-015 | Security and supply-chain gates are incomplete. | Threat models, ASVS/MASVS review, authorization tests, secret scan, dependency/license scan, signed SBOM/artifacts, penetration findings closed, and no critical/high vulnerability. | Open |
| LB-016 | Accessibility, localization, RTL, device, and performance gates are unproven. | Automated/manual audit and device-matrix results meet documented crash, startup, latency, jank, dynamic type, screen reader, contrast, touch target, and RTL budgets. | Open |
| LB-017 | Legal/public routes are gated and contain no approved publishable content. | Reachable HTTPS privacy, terms, support, community, copyright, and account deletion/export pages with owner-approved content plus accurate store privacy/data-safety declarations. | Open |
| LB-018 | Signed release artifacts and store approvals are absent. | Production-signed AAB, TestFlight archive, store metadata/review evidence, active IAP products, staged rollout plan, reviewer access, and signing custody verification. | Open |
| LB-019 | Final release evidence is incomplete. | Every mandatory item in `docs/RELEASE_CHECKLIST.md` is checked with evidence, no blocking defect remains, and the accountable owner records go/no-go. | Open |

If all engineering work is complete but an owner account, provider approval, legal decision, or store review remains unresolved, the correct status is still **BLOCKED — NOT PUBLISH-READY**.
