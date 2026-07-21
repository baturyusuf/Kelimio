import type { Metadata } from "next";
import { PublicationDocument } from "@/components/publication-document";
import { getDocumentPublication, publicationMetadata } from "@/lib/publication";

export const dynamic = "force-dynamic";

export function generateMetadata(): Metadata {
  return publicationMetadata(
    "Kullanım Koşulları",
    getDocumentPublication("terms").isPublished,
  );
}

export default function TermsPage() {
  return <PublicationDocument kind="terms" title="Kullanım Koşulları" />;
}
