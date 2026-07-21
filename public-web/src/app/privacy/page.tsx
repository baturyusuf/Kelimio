import type { Metadata } from "next";
import { PublicationDocument } from "@/components/publication-document";
import { getDocumentPublication, publicationMetadata } from "@/lib/publication";

export const dynamic = "force-dynamic";

export function generateMetadata(): Metadata {
  return publicationMetadata(
    "Gizlilik Politikası",
    getDocumentPublication("privacy").isPublished,
  );
}

export default function PrivacyPage() {
  return <PublicationDocument kind="privacy" title="Gizlilik Politikası" />;
}
