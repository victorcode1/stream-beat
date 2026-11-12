import type { Metadata } from "next";
export function pageMetadata(
  title: string,
  description: string,
  path: string,
): Metadata {
  return {
    title: path === "/" ? { absolute: `${title} · StreamBeat` } : title,
    description,
    alternates: { canonical: path },
    openGraph: {
      title: `${title} · StreamBeat`,
      description,
      url: path,
      siteName: "StreamBeat",
      locale: "es_LA",
      type: "website",
      images: [
        {
          url: "/social.png",
          width: 1024,
          height: 500,
          alt: "StreamBeat, radio en vivo",
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title: `${title} · StreamBeat`,
      description,
      images: ["/social.png"],
    },
  };
}
