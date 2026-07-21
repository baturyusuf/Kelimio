import type { Metadata } from "next";
import Link from "next/link";
import { ContentShell } from "@/components/content-shell";

export const metadata: Metadata = {
  robots: { follow: false, index: false, nocache: true },
  title: "Sayfa kullanıma açık değil",
};

export default function NotFound() {
  return (
    <ContentShell eyebrow="Kullanılamıyor" title="Bu sayfa kullanıma açık değil">
      <div className="content-card">
        <p>İstenen içerik yayımlanmamış olabilir veya adres artık geçerli olmayabilir.</p>
        <div className="actions">
          <Link className="button button--primary" href="/">
            Ana sayfaya dön
          </Link>
        </div>
      </div>
    </ContentShell>
  );
}
