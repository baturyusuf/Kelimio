import Link from "next/link";

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <span>Kelimio</span>
      <nav aria-label="Yasal ve destek bağlantıları">
        <Link href="/support">Destek</Link>
        <Link href="/privacy">Gizlilik</Link>
        <Link href="/terms">Kullanım koşulları</Link>
        <Link href="/community-guidelines">Topluluk kuralları</Link>
        <Link href="/teacher-terms">Öğretmen koşulları</Link>
      </nav>
    </footer>
  );
}
