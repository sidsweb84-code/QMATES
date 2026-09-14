import type { Metadata } from "next";
import { PageHero } from "@/components/ui/PageHero";
import { ProjectCard } from "@/components/site/ProjectCard";
import { CTASection } from "@/components/site/CTASection";
import { Section } from "@/components/ui/Section";
import { Reveal } from "@/components/ui/Reveal";
import { projects } from "@/data/projects";
import { services } from "@/data/services";

export const metadata: Metadata = {
  title: "Portfolio",
  description:
    "Selected website projects by QMATES — solar, trades, hospitality, health, retail and professional services businesses across Queensland.",
  alternates: { canonical: "/portfolio" },
  openGraph: {
    title: "Portfolio — QMATES",
    description:
      "Selected website projects by QMATES for Queensland businesses, each with a full case study.",
    url: "/portfolio",
  },
};

const industries = [...new Set(projects.map((p) => p.category))];

export default function PortfolioPage() {
  return (
    <>
      <PageHero
        index="01"
        eyebrow="Portfolio"
        title={
          <>
            Work that has to earn
            <br />
            its <span className="accent-word text-reef">keep</span>.
          </>
        }
        lead="Six projects across six industries. Each one opens into a full case study covering the problem, the approach and the decisions behind the design."
        aside={
          <dl className="grid grid-cols-2 gap-x-6 gap-y-6">
            <div>
              <dt className="eyebrow text-dim">Projects</dt>
              <dd className="nums mt-2 font-display text-[1.75rem] font-bold text-bone">
                {projects.length}
              </dd>
            </div>
            <div>
              <dt className="eyebrow text-dim">Industries</dt>
              <dd className="nums mt-2 font-display text-[1.75rem] font-bold text-bone">
                {industries.length}
              </dd>
            </div>
            <div className="col-span-2">
              <dt className="eyebrow text-dim">Services applied</dt>
              <dd className="mt-2.5 flex flex-wrap gap-2">
                {services.slice(0, 4).map((s) => (
                  <span
                    key={s.id}
                    className="rounded-[var(--radius-xs)] border border-line px-2 py-1 text-[0.6875rem] text-mist"
                  >
                    {s.title}
                  </span>
                ))}
              </dd>
            </div>
          </dl>
        }
      />

      <Section size="lg">
        <Reveal className="mb-12 rounded-[var(--radius-lg)] border border-sand/25 bg-sand/[0.06] p-5 md:p-6">
          <p className="eyebrow mb-2.5 text-sand">A note on this portfolio</p>
          <p className="max-w-3xl text-meta text-mist">
            Every project below is a <strong className="font-semibold text-bone">sample build</strong>{" "}
            created to demonstrate how QMATES approaches each industry. They are not
            real clients, and no results, reviews or statistics have been invented.
            As real work is completed it replaces these entries directly.
          </p>
        </Reveal>

        <Reveal className="mb-12">
          <h2 className="text-h2 text-bone">Every project</h2>
          <p className="mt-4 max-w-xl text-meta text-mist">
            Ordered most recent first. Open any card for the full case study.
          </p>
        </Reveal>

        <div className="grid gap-x-8 gap-y-16 md:grid-cols-2 md:gap-y-20">
          {projects.map((project, i) => (
            <Reveal key={project.slug} delay={(i % 2) * 0.08}>
              <ProjectCard project={project} index={i} />
            </Reveal>
          ))}
        </div>
      </Section>

      <CTASection
        eyebrow="Your project"
        title="Your business could be the next one on this page."
        body="Tell me what you do and what the site needs to achieve. You will get a fixed written quote — no obligation."
        secondary={{ href: "/pricing", label: "See pricing" }}
      />
    </>
  );
}
