const baseUrl = new URL(
  process.env.NEXT_PUBLIC_SITE_URL || "https://streambeat-web.vercel.app",
);
if (!["https:", "http:"].includes(baseUrl.protocol))
  throw new Error("NEXT_PUBLIC_SITE_URL debe ser una URL HTTP o HTTPS.");
export const site = {
  name: "StreamBeat",
  url: baseUrl.origin,
  description:
    "Descubre emisoras de todo el mundo, explora el mapa y escucha tus favoritas en segundo plano. Radio en vivo para Android, sin crear una cuenta.",
  googlePlay:
    "https://play.google.com/store/apps/details?id=com.victorflores.streambeat",
  privacy: "https://victorcode1.github.io/stream-beat/privacy/",
  support: "https://github.com/victorcode1/stream-beat/issues",
  broadcasters: "https://victorcode1.github.io/stream-beat/broadcasters/",
};
export const navigation = [
  { href: "/funcionalidades", label: "Funcionalidades" },
  { href: "/descargar", label: "Descargar" },
  { href: "/contacto", label: "Contacto" },
] as const;
