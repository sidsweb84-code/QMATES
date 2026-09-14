import type { MetadataRoute } from "next";

/* Required by `output: "export"` — emits the file at build time. */
export const dynamic = "force-static";
import { projects } from "@/data/projects";
import { navItems, site } from "@/data/site";

export default function sitemap(): MetadataRoute.Sitemap {
  const now = new Date();

  const pages = [...navItems.map((n) => n.href), "/quote"].map((href) => ({
    url: `${site.url}${href === "/" ? "" : href}`,
    lastModified: now,
    changeFrequency: "monthly" as const,
    priority: href === "/" ? 1 : 0.8,
  }));

  const caseStudies = projects.map((p) => ({
    url: `${site.url}/portfolio/${p.slug}`,
    lastModified: now,
    changeFrequency: "monthly" as const,
    priority: 0.6,
  }));

  return [...pages, ...caseStudies];
}
