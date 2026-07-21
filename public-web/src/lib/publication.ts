import type { Metadata } from "next";

export type DocumentKind =
  | "accountDeletion"
  | "communityGuidelines"
  | "privacy"
  | "teacherTerms"
  | "terms";

type EnvironmentNames = {
  approved: string;
  content: string;
  version: string;
};

const documentEnvironment: Record<DocumentKind, EnvironmentNames> = {
  accountDeletion: {
    approved: "KELIMIO_ACCOUNT_DELETION_APPROVED",
    content: "KELIMIO_ACCOUNT_DELETION_TEXT",
    version: "KELIMIO_ACCOUNT_DELETION_VERSION",
  },
  communityGuidelines: {
    approved: "KELIMIO_COMMUNITY_GUIDELINES_APPROVED",
    content: "KELIMIO_COMMUNITY_GUIDELINES_TEXT",
    version: "KELIMIO_COMMUNITY_GUIDELINES_VERSION",
  },
  privacy: {
    approved: "KELIMIO_PRIVACY_APPROVED",
    content: "KELIMIO_PRIVACY_TEXT",
    version: "KELIMIO_PRIVACY_VERSION",
  },
  teacherTerms: {
    approved: "KELIMIO_TEACHER_TERMS_APPROVED",
    content: "KELIMIO_TEACHER_TERMS_TEXT",
    version: "KELIMIO_TEACHER_TERMS_VERSION",
  },
  terms: {
    approved: "KELIMIO_TERMS_APPROVED",
    content: "KELIMIO_TERMS_TEXT",
    version: "KELIMIO_TERMS_VERSION",
  },
};

const VERSION_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function environmentValue(name: string): string {
  return process.env[name]?.trim() ?? "";
}

function normalizedContent(name: string): string {
  return environmentValue(name).replaceAll("\\n", "\n");
}

export type DocumentPublication = {
  content: string;
  isPublished: boolean;
  version: string;
};

export function getDocumentPublication(kind: DocumentKind): DocumentPublication {
  const names = documentEnvironment[kind];
  const content = normalizedContent(names.content);
  const version = environmentValue(names.version);
  const isPublished =
    environmentValue(names.approved) === "true" &&
    VERSION_PATTERN.test(version) &&
    content.length > 0;

  return { content, isPublished, version };
}

export type SupportPublication = {
  email: string;
  isPublished: boolean;
  version: string;
};

export function getSupportPublication(): SupportPublication {
  const email = environmentValue("KELIMIO_SUPPORT_EMAIL");
  const version = environmentValue("KELIMIO_SUPPORT_VERSION");
  const isPublished =
    environmentValue("KELIMIO_SUPPORT_APPROVED") === "true" &&
    VERSION_PATTERN.test(version) &&
    EMAIL_PATTERN.test(email);

  return { email, isPublished, version };
}

export function isProductionRuntime(): boolean {
  return process.env.NODE_ENV === "production";
}

export function publicationMetadata(title: string, isPublished: boolean): Metadata {
  return {
    title,
    robots: isPublished
      ? { follow: true, index: true }
      : { follow: false, index: false, nocache: true },
  };
}

export function publicationParagraphs(content: string): string[] {
  return content
    .split(/\r?\n\s*\r?\n/)
    .map((paragraph) => paragraph.trim())
    .filter(Boolean);
}
