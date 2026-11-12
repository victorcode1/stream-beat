import { DownloadButton } from "./download-button";
export function DownloadSection() {
  return (
    <section
      className="download-section container"
      aria-labelledby="download-title"
    >
      <div>
        <p className="kicker">Tu próxima emisora te espera</p>
        <h2 id="download-title">Dale play a otro lugar.</h2>
        <p>Instala StreamBeat y empieza a explorar. Sin crear una cuenta.</p>
      </div>
      <DownloadButton />
    </section>
  );
}
