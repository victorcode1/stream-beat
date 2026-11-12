import Link from "next/link";
import { DownloadButton } from "@/components/download-button";
import { DownloadSection } from "@/components/download-section";
import { PhoneScreenshot } from "@/components/phone-screenshot";
import { FeatureIcon } from "@/components/feature-icon";
import { Faq } from "@/components/faq";
import { features } from "@/content/features";
import { pageMetadata } from "@/lib/metadata";
import { site } from "@/lib/site";
export const metadata = pageMetadata(
  "Radio en vivo de todo el mundo",
  site.description,
  "/",
);
export default function Home() {
  const schema = {
    "@context": "https://schema.org",
    "@type": "MobileApplication",
    name: site.name,
    description: site.description,
    url: site.url,
    downloadUrl: site.googlePlay,
    operatingSystem: "Android",
    applicationCategory: "MultimediaApplication",
    inLanguage: ["es", "en", "pt-BR"],
    offers: {
      "@type": "Offer",
      price: "0",
      priceCurrency: "USD",
      description:
        "Radio gratis con anuncios. Aportes opcionales dentro de la app.",
    },
  };
  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify(schema).replace(/</g, "\u003c"),
        }}
      />
      <section className="hero container" aria-labelledby="hero-title">
        <div className="hero-copy">
          <p className="live-label">
            <span />
            Radio en vivo, a tu ritmo
          </p>
          <h1 id="hero-title">
            Hay un mundo
            <br />
            sonando
            <br />
            ahí fuera.
          </h1>
          <p className="lead">
            Una emisora cerca de casa. Otra al otro lado del planeta. Encuentra
            tu próxima favorita con StreamBeat.
          </p>
          <DownloadButton />
          <p className="download-note">
            Para Android. Gratis para empezar. Sin registro.
          </p>
          <Link className="text-link" href="/funcionalidades">
            Explora lo que puedes hacer <span aria-hidden="true">↗</span>
          </Link>
        </div>
        <div className="hero-visual">
          <div className="orbit orbit-one" />
          <div className="orbit orbit-two" />
          <div className="orbit orbit-three" />
          <span className="orbit-dot dot-one" />
          <span className="orbit-dot dot-two" />
          <span className="visual-caption caption-top">De aquí. De allá.</span>
          <PhoneScreenshot
            name="home"
            alt="Inicio de StreamBeat con recomendaciones y emisoras escuchadas recientemente"
            priority
          />
          <span className="visual-caption caption-bottom">
            Siempre en tu frecuencia.
          </span>
        </div>
      </section>
      <div className="frequency-strip">
        <div className="container">
          <span>Descubre por país</span>
          <span>Explora el mapa</span>
          <span>Guarda tus favoritas</span>
          <span>Escucha en segundo plano</span>
        </div>
      </div>
      <section
        className="section container discovery"
        aria-labelledby="map-title"
      >
        <div className="map-screen">
          <PhoneScreenshot
            name="map"
            alt="Mapa de StreamBeat para explorar emisoras por ubicación"
          />
          <span className="map-coordinate" aria-hidden="true">
            Un mapa. Muchas formas de escuchar.
          </span>
        </div>
        <div>
          <p className="kicker">Escucha más allá de lo conocido</p>
          <h2 id="map-title">
            Cambia de lugar.
            <br />
            Cambia de sonido.
          </h2>
          <p className="lead">
            Recorre el mapa y descubre qué suena en otros países. O busca esa
            emisora que te hace sentir en casa.
          </p>
          <p>
            Explora por ubicación, país o género. Tú eliges la emisora; su
            programación pone el resto.
          </p>
          <Link href="/funcionalidades" className="text-link">
            Conoce el explorador de radio <span aria-hidden="true">↗</span>
          </Link>
        </div>
      </section>
      <section className="section container" aria-labelledby="features-title">
        <div className="section-heading">
          <div>
            <p className="kicker">Hecha para escuchar</p>
            <h2 id="features-title">
              Tu radio.
              <br />
              Tu forma de llevarla.
            </h2>
          </div>
          <p>
            De descubrir una emisora a volver a ella cada día. Todo en el mismo
            lugar.
          </p>
        </div>
        <div className="feature-grid">
          {features.slice(1, 4).map((feature) => (
            <article key={feature.title}>
              <FeatureIcon name={feature.icon} />
              <h3>{feature.title}</h3>
              <p>{feature.description}</p>
            </article>
          ))}
        </div>
      </section>
      <section className="library-band">
        <div className="container library-inner">
          <div>
            <p className="kicker">Lo que te gusta, contigo</p>
            <h2>
              Una biblioteca
              <br />
              muy tuya.
            </h2>
            <p className="lead">
              Tus favoritas, tus listas y tu historial se guardan en el
              dispositivo. Entra, elige una emisora y sigue con tu día.
            </p>
            <p>
              Sin cuenta de StreamBeat. Sin sincronización en la nube. Para
              escuchar radio en vivo necesitas Internet.
            </p>
          </div>
          <div className="waveform" aria-hidden="true">
            {[25, 44, 70, 38, 90, 55, 100, 65, 42, 78, 32, 58, 86, 46, 24].map(
              (height, i) => (
                <span key={i} style={{ height: `${height}%` }} />
              ),
            )}
          </div>
        </div>
      </section>
      <section className="section container" aria-labelledby="screens-title">
        <div className="section-heading">
          <div>
            <p className="kicker">Dentro de StreamBeat</p>
            <h2 id="screens-title">
              Así se ve.
              <br />
              Así de sencillo.
            </h2>
          </div>
          <p>Capturas reales de la edición de radio.</p>
        </div>
        <div className="screenshot-gallery">
          {[
            {
              name: "home" as const,
              title: "Descubre",
              text: "Un punto de partida para encontrar tu próxima emisora.",
            },
            {
              name: "radio" as const,
              title: "Explora",
              text: "Radio por país y género, con tus favoritas siempre a mano.",
            },
            {
              name: "map" as const,
              title: "Recorre",
              text: "Un mapa para descubrir sonidos de otros lugares.",
            },
          ].map((shot) => (
            <figure key={shot.name}>
              <PhoneScreenshot
                name={shot.name}
                alt={`${shot.title}: pantalla real de StreamBeat`}
              />
              <figcaption>
                <h3>{shot.title}</h3>
                <p>{shot.text}</p>
              </figcaption>
            </figure>
          ))}
        </div>
      </section>
      <Faq />
      <DownloadSection />
    </>
  );
}
