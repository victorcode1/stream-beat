import Link from "next/link";
import { Brand } from "./brand";
import { navigation } from "@/lib/site";
export function Header() {
  return (
    <header className="header">
      <div className="container header-inner">
        <Brand />
        <nav aria-label="Navegación principal">
          {navigation.map((item) => (
            <Link key={item.href} href={item.href}>
              {item.label}
            </Link>
          ))}
        </nav>
        <Link
          className="button button-small desktop-download"
          href="/descargar"
        >
          Descargar la app
        </Link>
      </div>
    </header>
  );
}
