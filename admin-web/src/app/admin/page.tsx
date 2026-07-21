import { notFound } from "next/navigation";

export const dynamic = "force-dynamic";

export default function AdminPage() {
  // No environment flag can substitute for server-side OIDC, MFA, RBAC, and
  // audited authorization. The route stays absent until those controls exist.
  notFound();
}
