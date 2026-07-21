import type { ReactNode } from "react";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";

type ContentShellProps = {
  children: ReactNode;
  eyebrow: string;
  title: string;
};

export function ContentShell({ children, eyebrow, title }: ContentShellProps) {
  return (
    <>
      <SiteHeader />
      <main id="main-content" className="content-shell">
        <p className="eyebrow">{eyebrow}</p>
        <h1>{title}</h1>
        {children}
      </main>
      <SiteFooter />
    </>
  );
}
