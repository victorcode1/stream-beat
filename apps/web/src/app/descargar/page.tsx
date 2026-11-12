import { DownloadButton } from "@/components/download-button";
import { PhoneScreenshot } from "@/components/phone-screenshot";
import { Faq } from "@/components/faq";
import { pageMetadata } from "@/lib/metadata";
export const metadata = pageMetadata(
  "Descargar para Android",
  "Instala StreamBeat desde Google Play. Escucha radio en vivo, explora el mapa y guarda tus favoritas sin crear una cuenta.",
  "/descargar",
);
export default function DownloadPage() {
  return (
    <>
      <section className="container download-hero">
        <div>
          <p className="kicker">Descargar StreamBeat</p>
          <h1>
            Tu próxima
            <br />
            favorita está
            <br />a un play.
          </h1>
          <p className="lead">
            La edición de radio está disponible para Android en Google Play.
          </p>
          <DownloadButton />
          <p className="download-note">
            La tienda muestra la compatibilidad y disponibilidad para tu
            dispositivo.
          </p>
          <ul className="download-facts">
            <li>Escucha radio sin registrarte.</li>
            <li>Favoritos y listas guardados en el dispositivo.</li>
            <li>Internet necesario para escuchar las emisiones.</li>
          </ul>
          <p>
            La app puede mostrar anuncios. Consulta dentro de la app los aportes
            opcionales para quitarlos y las condiciones de la tienda.
          </p>
        </div>
        <PhoneScreenshot
          name="radio"
          alt="Emisoras de radio en la aplicación StreamBeat"
          priority
        />
      </section>
      <Faq />
    </>
  );
}
