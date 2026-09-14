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
    "Websites built by QMATES for Queensland businesses — wall and ceiling repair, smash repairs, guttering and more. Live sites, demo builds and case studies.",
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
        lead="Live sites, demo builds and concept work. Each one opens into a case study covering the problem, the approach and the decisions behind the design."
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
          <p className="eyebrow mb-2.5 text-sand">How to read this page</p>
          <p className="max-w-3xl text-meta text-mist">
            Every project is labelled for exactly what it is.{" "}
            <strong className="font-semibold text-bone">Live site</strong> means it is
            online and serving a real business.{" "}
            <strong className="font-semibold text-bone">Demo build</strong> means a real
            build published as a working demonstration.{" "}
            <strong className="font-semibold text-bone">Sample project</strong> means a
            concept piece, not a real client. No traffic figures, results or reviews
            are published anywhere on this site unless a client has agreed to them.
          </p>
        </Reveal>

        <Reveal className="mb-12">
          <h2 className="text-h2 text-bone">Every project</h2>
          <p className="mt-4 max-w-xl text-meta text-mist">
            Open any card for the case study, or follow the link in its header
            straight to the live build.
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
