import { site } from "@/lib/site";
import { pageMetadata } from "@/lib/metadata";
export const metadata = pageMetadata(
  "Contacto y soporte",
  "Obtén ayuda con StreamBeat, informa un problema o consulta los canales para emisoras y solicitudes de privacidad.",
  "/contacto",
);
export default function ContactPage() {
  return (
    <>
      <section className="page-heading container">
        <p className="kicker">Contacto y soporte</p>
        <h1>Te escuchamos.</h1>
        <p className="lead">
          Si algo no suena como debería, cuéntanos qué ocurre.
        </p>
      </section>
      <section
        className="container contact-grid"
        aria-label="Canales de contacto"
      >
        <article>
          <h2>Ayuda con la app</h2>
          <p>
            Informa un problema o sugiere una mejora en el canal oficial de
            soporte. Incluye tu dispositivo, versión de la app y los pasos para
            reproducirlo.
          </p>
          <a className="button" href={site.support}>
            Abrir canal de soporte
          </a>
          <p className="small">
            Las incidencias son públicas. No incluyas contraseñas, datos de pago
            ni documentos personales.
          </p>
        </article>
        <article>
          <h2>Emisoras y derechos</h2>
          <p>
            Si representas a una emisora y necesitas corregir información o
            solicitar una retirada, consulta el procedimiento para titulares.
          </p>
          <a className="text-link" href={site.broadcasters}>
            Consultar el canal para emisoras ↗
          </a>
          <h2>Privacidad</h2>
          <p>
            Conoce cómo se usan la ubicación opcional, los datos locales y los
            servicios externos.
          </p>
          <a className="text-link" href={site.privacy}>
            Leer la política de privacidad ↗
          </a>
        </article>
      </section>
    </>
  );
}
