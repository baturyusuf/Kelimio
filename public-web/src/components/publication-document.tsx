import { notFound } from "next/navigation";
import { ContentShell } from "@/components/content-shell";
import {
  type DocumentKind,
  getDocumentPublication,
  isProductionRuntime,
  publicationParagraphs,
} from "@/lib/publication";

type PublicationDocumentProps = {
  kind: DocumentKind;
  title: string;
};

export function PublicationDocument({ kind, title }: PublicationDocumentProps) {
  const publication = getDocumentPublication(kind);

  if (!publication.isPublished && isProductionRuntime()) {
    notFound();
  }

  if (!publication.isPublished) {
    return (
      <ContentShell eyebrow="Yayın kapısı" title={title}>
        <div className="content-card" role="status">
          <span className="status-badge">Yayımlanmadı</span>
          <p>
            Bu sayfa, yetkili onay ile sürümlü içerik yapılandırması tamamlanana
            kadar yalnızca geliştirme ortamında bu durum bildirimini gösterir.
          </p>
        </div>
      </ContentShell>
    );
  }

  return (
    <ContentShell eyebrow="Onaylı yayın" title={title}>
      <article className="content-card document-copy">
        <p className="publication-version">Sürüm: {publication.version}</p>
        {publicationParagraphs(publication.content).map((paragraph, index) => (
          <p key={`${publication.version}-${index}`}>{paragraph}</p>
        ))}
      </article>
    </ContentShell>
  );
}
