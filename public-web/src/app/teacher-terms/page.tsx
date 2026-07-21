import type { Metadata } from "next";
import { PublicationDocument } from "@/components/publication-document";
import { getDocumentPublication, publicationMetadata } from "@/lib/publication";

export const dynamic = "force-dynamic";

export function generateMetadata(): Metadata {
  return publicationMetadata(
    "Öğretmen Koşulları",
    getDocumentPublication("teacherTerms").isPublished,
  );
}

export default function TeacherTermsPage() {
  return (
    <PublicationDocument
      kind="teacherTerms"
      title="Öğretmen ve Kurs Sahibi Koşulları"
    />
  );
}
