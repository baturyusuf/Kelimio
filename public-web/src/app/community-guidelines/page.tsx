import type { Metadata } from "next";
import { PublicationDocument } from "@/components/publication-document";
import { getDocumentPublication, publicationMetadata } from "@/lib/publication";

export const dynamic = "force-dynamic";

export function generateMetadata(): Metadata {
  return publicationMetadata(
    "Topluluk Kuralları",
    getDocumentPublication("communityGuidelines").isPublished,
  );
}

export default function CommunityGuidelinesPage() {
  return (
    <PublicationDocument kind="communityGuidelines" title="Topluluk Kuralları" />
  );
}
