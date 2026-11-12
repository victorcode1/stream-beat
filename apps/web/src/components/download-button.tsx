import { site } from "@/lib/site";
export function DownloadButton() {
  return (
    <a className="button" href={site.googlePlay}>
      <svg
        aria-hidden="true"
        width="21"
        height="23"
        viewBox="0 0 21 23"
        fill="currentColor"
      >
        <path d="M1 1.5v20l17-10z" />
      </svg>
      <span>Descargar en Google Play</span>
    </a>
  );
}
