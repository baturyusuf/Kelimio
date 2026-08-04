import type { Metadata } from "next";
import { PublicationDocument } from "@/components/publication-document";
import { getDocumentPublication, publicationMetadata } from "@/lib/publication";

export const dynamic = "force-dynamic";

export function generateMetadata(): Metadata {
  return publicationMetadata(
    "Hesap Silme",
    getDocumentPublication("accountDeletion").isPublished,
  );
}

export default function AccountDeletionPage() {
  return <PublicationDocument kind="accountDeletion" title="Hesap ve veri silme" />;
}
