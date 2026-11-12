import { faqs } from "@/content/features";
export function Faq() {
  return (
    <section
      className="section container faq-layout"
      aria-labelledby="faq-title"
    >
      <div>
        <p className="kicker">Antes de darle play</p>
        <h2 id="faq-title">
          Preguntas
          <br />
          frecuentes.
        </h2>
      </div>
      <div className="faq-list">
        {faqs.map((faq) => (
          <details key={faq.question}>
            <summary>
              {faq.question}
              <span aria-hidden="true">+</span>
            </summary>
            <p>{faq.answer}</p>
          </details>
        ))}
      </div>
    </section>
  );
}
