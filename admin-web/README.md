# Kelimio internal administration web

This deployment is reserved for the future internal administration console.
It is globally `noindex`, and `/admin` always returns not found until server-side
OIDC, MFA, RBAC, and mutation audit are implemented. No environment flag can
turn the placeholder into an authorization mechanism.

Public, support, account-deletion, and legal pages belong to the separate
`public-web` deployment. Existing placeholder pages here are not approved
policies and are not a release surface.

Required public configuration:

- Future confidential OIDC settings must use server-only environment variables.

Never expose an OIDC client secret through a `NEXT_PUBLIC_*` variable.
