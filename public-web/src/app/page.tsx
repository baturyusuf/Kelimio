import Link from "next/link";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";

export default function Home() {
  return (
    <>
      <SiteHeader />
      <main id="main-content">
        <section className="hero">
          <div className="hero__content">
            <p className="eyebrow">Dilinizi bir adım ileri taşıyın</p>
            <h1>Öğrenenlerle öğretmenleri aynı kursta buluşturan platform.</h1>
            <p className="lead">
              Kelimio; çevrimiçi öğrenme, öğretmen tarafından hazırlanan kurslar
              ve skorsuz çevrimdışı pratiği güvenli bir deneyimde birleştirir.
            </p>
            <div className="actions" aria-label="Ana işlemler">
              <Link className="button button--primary" href="/support">
                Destek
              </Link>
              <Link className="button button--secondary" href="/account-deletion">
                Hesap silme
              </Link>
            </div>
          </div>
          <div className="hero__mark" aria-hidden="true">
            K
          </div>
        </section>
        <section className="feature-grid" aria-labelledby="features-heading">
          <h2 id="features-heading" className="visually-hidden">
            Kelimio özellikleri
          </h2>
          <article className="feature-card">
            <span>01</span>
            <h3>Gerçek ilerleme</h3>
            <p>Skor, enerji ve ilerleme sonuçları güvenli sunucu işlemleriyle hesaplanır.</p>
          </article>
          <article className="feature-card">
            <span>02</span>
            <h3>Öğretmen kursları</h3>
            <p>İçerik sürümleri korunur; öğrenci deneyimi güncellemelerde tutarlı kalır.</p>
          </article>
          <article className="feature-card">
            <span>03</span>
            <h3>Çevrimdışı pratik</h3>
            <p>İmzalı kurs paketleriyle bağlantı olmadan, skor dışı pratik yapılır.</p>
          </article>
        </section>
      </main>
      <SiteFooter />
    </>
  );
}
