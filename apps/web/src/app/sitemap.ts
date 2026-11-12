import type { MetadataRoute } from "next";
import { site, navigation } from "@/lib/site";
export default function sitemap(): MetadataRoute.Sitemap {
  return ["/", ...navigation.map((item) => item.href)].map((path) => ({
    url: `${site.url}${path === "/" ? "" : path}`,
    changeFrequency: "monthly",
    priority: path === "/" ? 1 : 0.7,
  }));
}
