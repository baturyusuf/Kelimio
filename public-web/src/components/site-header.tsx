import Link from "next/link";

export function SiteHeader() {
  return (
    <header className="site-header">
      <Link className="brand" href="/" aria-label="Kelimio ana sayfa">
        <span className="brand__mark" aria-hidden="true">
          K
        </span>
        Kelimio
      </Link>
      <nav className="site-nav" aria-label="Genel">
        <Link href="/support">Destek</Link>
        <Link href="/privacy">Gizlilik</Link>
        <Link href="/terms">Koşullar</Link>
        <Link href="/account-deletion">Hesap silme</Link>
      </nav>
    </header>
  );
}
