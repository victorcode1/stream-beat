import Link from "next/link";
export default function NotFound() {
  return (
    <section className="page-heading container">
      <p className="kicker">Página no encontrada</p>
      <h1>
        Por aquí
        <br />
        no hay señal.
      </h1>
      <p className="lead">La página que buscas no está disponible.</p>
      <Link className="button" href="/">
        Volver al inicio
      </Link>
    </section>
  );
}
