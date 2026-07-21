import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { ContentShell } from "@/components/content-shell";
import {
  getSupportPublication,
  isProductionRuntime,
  publicationMetadata,
} from "@/lib/publication";

export const dynamic = "force-dynamic";

export function generateMetadata(): Metadata {
  return publicationMetadata("Destek", getSupportPublication().isPublished);
}

export default function SupportPage() {
  const publication = getSupportPublication();

  if (!publication.isPublished && isProductionRuntime()) {
    notFound();
  }

  return (
    <ContentShell eyebrow="Yardım" title="Kelimio Destek">
      {publication.isPublished ? (
        <div className="content-card">
          <p className="publication-version">Sürüm: {publication.version}</p>
          <p>
            Destek ekibine{" "}
            <a className="inline-link" href={`mailto:${publication.email}`}>
              {publication.email}
            </a>{" "}
            adresinden ulaşabilirsiniz.
          </p>
        </div>
      ) : (
        <div className="content-card" role="status">
          <span className="status-badge">Yayımlanmadı</span>
          <p>
            Doğrulanmış destek kanalı ve sürümlü onay yapılandırılana kadar bu
            sayfa yalnızca geliştirme ortamında bu durum bildirimini gösterir.
          </p>
        </div>
      )}
    </ContentShell>
  );
}
