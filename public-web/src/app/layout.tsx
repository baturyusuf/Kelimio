import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  applicationName: "Kelimio",
  description: "Kelimio dil öğrenme ve kurs platformunun resmi web yüzeyi.",
  referrer: "strict-origin-when-cross-origin",
  title: {
    default: "Kelimio",
    template: "%s | Kelimio",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="tr">
      <body>
        <a className="skip-link" href="#main-content">
          Ana içeriğe geç
        </a>
        {children}
      </body>
    </html>
  );
}
