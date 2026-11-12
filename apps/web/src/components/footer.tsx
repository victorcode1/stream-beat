import Link from "next/link";
import { Brand } from "./brand";
import { site } from "@/lib/site";
export function Footer() {
  return (
    <footer className="footer container">
      <div>
        <Brand />
        <p>
          Radio de todo el mundo.
          <br />
          Un lugar para encontrar la tuya.
        </p>
      </div>
      <nav aria-label="Enlaces del pie de página">
        <Link href="/contacto">Contacto y soporte</Link>
        <a href={site.privacy}>Privacidad</a>
        <a href={site.broadcasters}>Emisoras y derechos</a>
      </nav>
      <p className="copyright">
        © {new Date().getFullYear()} StreamBeat.
        <br />
        Las emisiones pertenecen a sus respectivos titulares.
      </p>
    </footer>
  );
}
