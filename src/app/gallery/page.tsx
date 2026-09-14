import type { Metadata } from "next";
import { PageHero } from "@/components/ui/PageHero";
import { GalleryGrid } from "@/components/site/GalleryGrid";
import { CTASection } from "@/components/site/CTASection";
import { Section } from "@/components/ui/Section";

export const metadata: Metadata = {
  title: "Website Gallery",
  description:
    "A visual gallery of website designs by QMATES — home pages, quote flows, review pages and enquiry forms built for Queensland businesses.",
  alternates: { canonical: "/gallery" },
  openGraph: {
    title: "Website Gallery — QMATES",
    description: "Website designs by QMATES, filterable by industry.",
    url: "/gallery",
  },
};

export default function GalleryPage() {
  return (
    <>
      <PageHero
        index="02"
        eyebrow="Gallery"
        title={
          <>
            Every screen,
            <br />
            up <span className="accent-word text-reef">close</span>.
          </>
        }
        lead="Home pages, service pages, booking flows and product screens pulled out of every project. Filter by industry, or open any screen for a closer look."
      />

      <Section size="lg">
        <GalleryGrid />
      </Section>

      <CTASection
        eyebrow="Your turn"
        title="Which of these looks closest to what you need?"
        body="Mention it in your quote request and we can use it as a starting point for the direction."
        secondary={{ href: "/portfolio", label: "Read the case studies" }}
      />
    </>
  );
}
