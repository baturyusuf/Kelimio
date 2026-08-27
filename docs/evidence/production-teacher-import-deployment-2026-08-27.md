# Production Teacher Import Deployment — 2026-08-27

## Scope and result

The controlled internal-test teacher-import path defined by ADR-021 was applied
to the production-only AWS account in `eu-central-1`. This evidence does not
approve public teacher onboarding, public UGC, store release, or a production
course-tree editor.

The deployed immutable revision is
`04b325cf8456b0d1cc9a6ca2126feba9a940b60c`.

## Protected deployment evidence

- GitHub production deployment run
  `https://github.com/baturyusuf/Kelimio/actions/runs/33052926820` passed.
- The exact API, worker, and scanner images passed HIGH/CRITICAL Trivy gates;
  the API SBOM was retained by the protected workflow.
- Immutable image digests:
  - API: `sha256:4e78936c0954462c138aefe345b93beb90056f77e97c0f752a07000e3cc2948f`
  - worker: `sha256:0ea02faba5b625385e0630376e5ab41f5c58194412b73e341f22e8ef8a3ff066`
  - scanner: `sha256:75c0a6adfede74992f1b782d06f92883fc10ee3892aa4575afc67e0282fa3f48`
- The one-shot migration task exited successfully before API promotion.
- The promoted ECS API task became healthy and the public API Gateway
  readiness endpoint returned `{"status":"UP"}`.
- The follow-up protected Terraform plan run
  `https://github.com/baturyusuf/Kelimio/actions/runs/33053928239` reported
  `No changes`.

## Eligibility and scale-zero evidence

- The managed Cognito `kelimio-teachers` group was created without an IAM role
  or precedence and the uniquely matched owner account was assigned to it.
  No username, email address, token, or credential is retained here.
- The import-worker ECS service was active at desired/running/pending `0/0/0`.
- Application Auto Scaling was active with minimum `0`, maximum `1`, and both
  scale-out and scale-in policies attached.
- The import queue and import DLQ each contained zero visible, in-flight, and
  delayed messages.
- The empty-queue alarm was active and the non-empty alarm was healthy, with
  alarm actions enabled.

## Fargate runtime proof

A one-shot task using the deployed import-worker task definition was started on
the production worker network without placing a synthetic message on the
course-import queue. The scanner and worker containers both reached `RUNNING`,
and the task reached `HEALTHY` after ClamAV refreshed its definitions. Both
containers dropped all Linux capabilities; the scanner ran as its unprivileged
account. The verification task was then stopped and the managed worker service
remained at `0/0/0`.

## Gates intentionally still open

- A controlled physical-device run must upload a reviewed real workbook,
  accept the exact authoring terms, approve and commit the resulting draft,
  and explicitly publish it.
- The same production canary must retain evidence for malware rejection,
  immutable quarantine/archive/version binding, queue and DLQ behavior,
  natural alarm-driven scale from zero to one and back to zero, and rollback.
- Public author eligibility, moderation, UGC/legal policy, retention and legal
  hold, the complete production course-tree editor, supported independent
  deployment approval, WAF/custom DNS, and public/store release gates remain
  open in `docs/OWNER_ACTIONS.md`, `docs/LAUNCH_BLOCKERS.md`, and
  `docs/RELEASE_CHECKLIST.md`.
