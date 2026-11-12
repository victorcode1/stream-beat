import { features } from "@/content/features";
import { FeatureIcon } from "@/components/feature-icon";
import { DownloadSection } from "@/components/download-section";
import { pageMetadata } from "@/lib/metadata";
export const metadata = pageMetadata(
  "Funcionalidades",
  "Mapa de emisoras, radio por país y género, favoritos, listas y reproducción en segundo plano con StreamBeat.",
  "/funcionalidades",
);
export default function FeaturesPage() {
  return (
    <>
      <section className="page-heading container">
        <p className="kicker">Funcionalidades</p>
        <h1>
          Todo empieza
          <br />
          con una emisora.
        </h1>
        <p className="lead">
          Descubre, escucha y guarda. StreamBeat reúne las herramientas para
          hacer de la radio parte de tu día.
        </p>
      </section>
      <section
        className="container feature-details"
        aria-label="Funciones de StreamBeat"
      >
        {features.map((feature) => (
          <article key={feature.title}>
            <FeatureIcon name={feature.icon} />
            <div>
              <h2>{feature.title}</h2>
              <p className="lead">{feature.description}</p>
              <p>{feature.detail}</p>
            </div>
          </article>
        ))}
      </section>
      <DownloadSection />
    </>
  );
}
