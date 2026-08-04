# Kelimio public web

This standalone Next.js application owns Kelimio's public, support, legal, and
account-deletion routes. It is intentionally separate from the internal admin
application.

## Publication safety

Legal and account-deletion pages are not legal documents until approved content
is supplied. In development, missing content renders an explicit publication
gate with `noindex`. In production, the same route returns `404` unless all
three server-only values for that document are valid:

- `KELIMIO_<DOCUMENT>_APPROVED=true`
- `KELIMIO_<DOCUMENT>_VERSION=<approved-version>`
- `KELIMIO_<DOCUMENT>_TEXT=<approved-full-text>`

Support follows the same rule with `KELIMIO_SUPPORT_EMAIL` in place of text.
The email must be syntactically valid. Do not use `NEXT_PUBLIC_*` variables for
these values, and do not enable a route until the accountable owner has recorded
the matching approval and version.

Copy `.env.example` to `.env.local` only for local preview. The committed example
contains no legal text, contact data, or approval.

## Checks

```powershell
pnpm install --frozen-lockfile
pnpm lint
pnpm typecheck
pnpm build
pnpm test:release-gates
```
