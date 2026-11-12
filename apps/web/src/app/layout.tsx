import type { Metadata, Viewport } from "next";
import localFont from "next/font/local";
import { Header } from "@/components/header";
import { Footer } from "@/components/footer";
import { site } from "@/lib/site";
import "./globals.css";
const geist = localFont({
  src: "../assets/geist-latin.woff2",
  variable: "--font-geist",
  display: "swap",
  weight: "100 900",
});
export const metadata: Metadata = {
  metadataBase: new URL(site.url),
  title: { default: "StreamBeat · Radio en vivo", template: "%s · StreamBeat" },
  description: site.description,
  applicationName: site.name,
  icons: { icon: "/icon.png", apple: "/icon.png" },
};
export const viewport: Viewport = { themeColor: "#0c242a" };
export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="es">
      <body className={geist.variable}>
        <a className="skip-link" href="#contenido">
          Saltar al contenido
        </a>
        <Header />
        <main id="contenido" tabIndex={-1}>
          {children}
        </main>
        <Footer />
      </body>
    </html>
  );
}
