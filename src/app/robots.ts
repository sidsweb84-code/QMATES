import type { MetadataRoute } from "next";

/* Required by `output: "export"` — emits the file at build time. */
export const dynamic = "force-static";
import { site } from "@/data/site";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: { userAgent: "*", allow: "/", disallow: "/api/" },
    sitemap: `${site.url}/sitemap.xml`,
  };
}
