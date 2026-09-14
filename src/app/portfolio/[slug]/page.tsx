import type { Metadata } from "next";
import Link from "next/link";
import Image from "next/image";
import { notFound } from "next/navigation";
import { adjacentProjects, displayUrl, getProject, projects } from "@/data/projects";
import { site } from "@/data/site";
import { Section } from "@/components/ui/Section";
import { Reveal, Stagger, StaggerItem } from "@/components/ui/Reveal";
import { Eyebrow } from "@/components/ui/SectionHeading";
import { ButtonAnchor } from "@/components/ui/Button";
import { ArrowLeft, ArrowRight, Check } from "@/components/ui/Icon";
import { StatusTag } from "@/components/site/ProjectCard";
import {
  BrowserFrame,
  MobileSitePreview,
  PhoneFrame,
  SitePreview,
} from "@/components/site/SitePreview";
import { CTASection } from "@/components/site/CTASection";

/* Every case study is prerendered at build time. */
export function generateStaticParams() {
  return projects.map((p) => ({ slug: p.slug }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const project = getProject(slug);
  if (!project) return { title: "Project not found" };

  const description = `${project.summary} A ${project.industry.toLowerCase()} website case study by ${site.name}.`;
  return {
    title: `${project.name} — ${project.industry}`,
    description,
    alternates: { canonical: `/portfolio/${project.slug}` },
    openGraph: {
      title: `${project.name} — ${site.name}`,
      description,
      url: `/portfolio/${project.slug}`,
      type: "article",
    },
  };
}

export default async function ProjectPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const project = getProject(slug);
  if (!project) notFound();

  const { prev, next } = adjacentProjects(project.slug);
  const hasScreenshots = project.screenshots.length > 0;

  return (
    <>
      {/* ==================== HERO ==================== */}
      <header className="grain relative isolate overflow-hidden border-b border-line bg-ink-2">
        <div
          aria-hidden="true"
          className="bloom -top-48 left-1/2 h-[26rem] w-[26rem] -translate-x-1/2 bg-reef/10 md:w-[52rem]"
        />
        <div className="shell relative z-10 pt-28 pb-16 md:pt-36 md:pb-20">
          <Reveal direction="none">
            <Link
              href="/portfolio"
              className="group/back inline-flex min-h-9 items-center gap-2 text-meta text-mist transition-colors duration-[var(--duration-base)] hover:text-reef"
            >
              <ArrowLeft
                size={16}
                className="transition-transform duration-[var(--duration-base)] ease-[var(--ease-out-expo)] group-hover/back:-translate-x-1"
              />
              All projects
            </Link>
          </Reveal>

          <div className="mt-8 grid gap-10 lg:grid-cols-[minmax(0,1.45fr)_minmax(0,1fr)] lg:gap-16">
            <Reveal delay={0.05}>
              <Eyebrow className="mb-4">
                {project.category} &middot; {project.year}
              </Eyebrow>
              <h1 className="text-hero text-bone">{project.name}</h1>
              <p className="mt-6 max-w-2xl text-lead text-mist">{project.intro}</p>
              <div className="mt-6 flex flex-wrap items-center gap-3">
                <StatusTag project={project} />
                {project.liveUrl ? (
                  <ButtonAnchor
                    href={project.liveUrl}
                    target="_blank"
                    rel="noreferrer noopener"
                    variant="quiet"
                    size="sm"
                    withArrow
                  >
                    Visit the live site
                  </ButtonAnchor>
                ) : null}
              </div>
            </Reveal>

            <Reveal delay={0.12}>
              <dl className="grid grid-cols-2 gap-x-6 gap-y-6 rounded-[var(--radius-lg)] border border-line bg-surface/60 p-6">
                <div>
                  <dt className="eyebrow text-dim">Industry</dt>
                  <dd className="mt-2 text-meta text-bone">{project.industry}</dd>
                </div>
                <div>
                  <dt className="eyebrow text-dim">Location</dt>
                  <dd className="mt-2 text-meta text-bone">{project.location}</dd>
                </div>
                {project.pages > 0 ? (
                  <div>
                    <dt className="eyebrow text-dim">Pages</dt>
                    <dd className="nums mt-2 text-meta text-bone">{project.pages}</dd>
                  </div>
                ) : null}
                <div>
                  <dt className="eyebrow text-dim">Year</dt>
                  <dd className="nums mt-2 text-meta text-bone">{project.year}</dd>
                </div>
                <div className="col-span-2">
                  <dt className="eyebrow text-dim">Services</dt>
                  <dd className="mt-2.5 flex flex-wrap gap-2">
                    {project.services.map((s) => (
                      <span
                        key={s}
                        className="rounded-[var(--radius-xs)] border border-line px-2 py-1 text-[0.6875rem] text-mist"
                      >
                        {s}
                      </span>
                    ))}
                  </dd>
                </div>
              </dl>
            </Reveal>
          </div>

          {/* --- lead visual --- */}
          <Reveal delay={0.18} className="mt-14">
            {hasScreenshots ? (
              <div className="overflow-hidden rounded-[var(--radius-lg)] border border-line-strong">
                <Image
                  src={project.screenshots[0].src}
                  alt={project.screenshots[0].alt}
                  width={1600}
                  height={1000}
                  priority
                  sizes="(max-width: 1024px) 100vw, 1200px"
                  className="h-auto w-full"
                />
              </div>
            ) : project.preview ? (
              <BrowserFrame url={displayUrl(project)}>
                <SitePreview project={project} />
              </BrowserFrame>
            ) : (
              <div className="overflow-hidden rounded-[var(--radius-lg)] border border-line">
                <SitePreview project={project} aspect="aspect-[16/7]" />
              </div>
            )}
            {project.preview || hasScreenshots ? (
              <p className="mt-3 text-[0.75rem] text-dim">
                {hasScreenshots
                  ? project.screenshots[0].alt
                  : "Design mockup of the home page — replaced by a real screenshot once the project is live."}
              </p>
            ) : null}
          </Reveal>
        </div>
      </header>

      {/* ==================== NARRATIVE ==================== */}
      {project.challenge ? (
      <Section size="lg">
        <div className="grid gap-14 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.6fr)] lg:gap-20">
          <Reveal className="lg:sticky lg:top-28 lg:self-start">
            <Eyebrow className="mb-4">The brief</Eyebrow>
            <h2 className="text-h2 text-bone">
              What the site had to <span className="accent-word text-reef">solve</span>
            </h2>
          </Reveal>

          <div className="flex flex-col gap-12">
            {[
              { label: "Challenge", body: project.challenge },
              { label: "Approach", body: project.approach },
              { label: "Design direction", body: project.designDirection },
            ].map((block, i) => (
              <Reveal key={block.label} delay={i * 0.06} className="rule-t pt-7">
                <h3 className="eyebrow mb-4 text-sand">{block.label}</h3>
                <p className="max-w-2xl text-lead text-mist">{block.body}</p>
              </Reveal>
            ))}
          </div>
        </div>
      </Section>
      ) : null}

      {/* ==================== KEY FEATURES ==================== */}
      {project.features.length > 0 ? (
      <Section tone="raised" size="lg">
        <Reveal>
          <Eyebrow className="mb-4">Key features</Eyebrow>
          <h2 className="max-w-2xl text-h2 text-bone">
            The parts that do the actual work
          </h2>
        </Reveal>

        <Stagger className="mt-12 grid gap-px overflow-hidden rounded-[var(--radius-lg)] border border-line bg-line md:grid-cols-2">
          {project.features.map((f, i) => (
            <StaggerItem key={f.title} className="group/f bg-ink-2 p-7 md:p-8">
              <span className="eyebrow nums text-dim">
                {String(i + 1).padStart(2, "0")}
              </span>
              <h3 className="mt-4 text-h3 text-bone">{f.title}</h3>
              <p className="mt-3 text-meta text-mist">{f.body}</p>
            </StaggerItem>
          ))}
        </Stagger>
      </Section>
      ) : null}

      {/* ==================== MOBILE ==================== */}
      {project.mobileNote ? (
      <Section size="lg">
        <div className="grid items-center gap-14 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] lg:gap-20">
          <Reveal>
            <Eyebrow className="mb-4">Mobile experience</Eyebrow>
            <h2 className="text-h2 text-bone">
              Designed for a phone <span className="accent-word text-sand">first</span>
            </h2>
            <p className="mt-6 max-w-lg text-lead text-mist">{project.mobileNote}</p>

            <ul className="mt-8 flex flex-col gap-3">
              {[
                "Touch targets sized for thumbs, not cursors",
                "Correct keyboard for every input type",
                "No horizontal scrolling at any width",
                "Tested on real devices, not just a resized window",
              ].map((item) => (
                <li key={item} className="flex items-start gap-2.5 text-meta text-mist">
                  <Check size={16} className="mt-0.5 shrink-0 text-reef" />
                  {item}
                </li>
              ))}
            </ul>
          </Reveal>

          <Reveal className="flex justify-center lg:justify-end">
            <PhoneFrame className="w-[15rem] sm:w-[17rem]">
              <MobileSitePreview project={project} />
            </PhoneFrame>
          </Reveal>
        </div>
      </Section>
      ) : null}

      {/* ==================== GALLERY ==================== */}
      {project.gallery.length > 0 ? (
      <Section tone="raised" size="lg">
        <Reveal>
          <Eyebrow className="mb-4">Screens</Eyebrow>
          <h2 className="max-w-2xl text-h2 text-bone">Across the site</h2>
          <p className="mt-5 max-w-xl text-meta text-dim">
            {hasScreenshots
              ? "Screens from the live site."
              : "Design mockups of the key templates. Real screenshots replace these once the project ships."}
          </p>
        </Reveal>

        <Stagger className="mt-12 flex flex-col gap-10">
          {project.gallery.map((shot, i) => (
            <StaggerItem key={shot.caption}>
              <figure
                className={
                  i % 2 === 1 ? "lg:ml-auto lg:w-[88%]" : "lg:mr-auto lg:w-[88%]"
                }
              >
                <BrowserFrame url={displayUrl(project)}>
                  <SitePreview project={project} layout={shot.layout} />
                </BrowserFrame>
                <figcaption className="mt-3 flex items-center gap-3 text-[0.75rem] text-dim">
                  <span className="nums">{String(i + 1).padStart(2, "0")}</span>
                  <span aria-hidden="true" className="h-px w-6 bg-line-strong" />
                  {shot.caption}
                </figcaption>
              </figure>
            </StaggerItem>
          ))}
        </Stagger>
      </Section>
      ) : null}

      {/* ==================== RESULTS ==================== */}
      <Section size="md">
        <Reveal className="rounded-[var(--radius-lg)] border border-line bg-surface/50 p-7 md:p-10">
          <Eyebrow className="mb-4">Results</Eyebrow>
          {project.outcomes ? (
            <ul className="grid gap-6 md:grid-cols-3">
              {project.outcomes.map((o) => (
                <li key={o} className="text-lead text-bone">
                  {o}
                </li>
              ))}
            </ul>
          ) : (
            <>
              <h2 className="max-w-2xl text-h3 text-bone">
                No results are published for this project.
              </h2>
              <p className="mt-4 max-w-2xl text-meta text-mist">
                {project.status === "live"
                  ? "Traffic and enquiry figures for this site are the client's to share, not mine. Nothing is published here unless they have agreed to it and it can be evidenced."
                  : "This is a demonstration build, so there is no live traffic, no enquiry data and no client feedback to report. Rather than invent figures, this section stays empty until there is something real to put in it."}
              </p>
            </>
          )}
        </Reveal>
      </Section>

      {/* ==================== PREV / NEXT ==================== */}
      <Section tone="raised" size="sm" as="div">
        <nav aria-label="Project navigation" className="grid gap-px overflow-hidden rounded-[var(--radius-lg)] border border-line bg-line md:grid-cols-2">
          {prev ? (
            <Link
              href={`/portfolio/${prev.slug}`}
              className="group/nav flex items-center gap-4 bg-ink-2 p-6 transition-colors duration-[var(--duration-base)] hover:bg-surface md:p-8"
            >
              <ArrowLeft
                size={20}
                className="shrink-0 text-reef transition-transform duration-[var(--duration-base)] ease-[var(--ease-out-expo)] group-hover/nav:-translate-x-1"
              />
              <span className="min-w-0">
                <span className="eyebrow block text-dim">Previous</span>
                <span className="mt-1.5 block truncate font-display text-h3 text-bone">
                  {prev.name}
                </span>
              </span>
            </Link>
          ) : null}
          {next ? (
            <Link
              href={`/portfolio/${next.slug}`}
              className="group/nav flex items-center justify-end gap-4 bg-ink-2 p-6 text-right transition-colors duration-[var(--duration-base)] hover:bg-surface md:p-8"
            >
              <span className="min-w-0">
                <span className="eyebrow block text-dim">Next</span>
                <span className="mt-1.5 block truncate font-display text-h3 text-bone">
                  {next.name}
                </span>
              </span>
              <ArrowRight
                size={20}
                className="shrink-0 text-reef transition-transform duration-[var(--duration-base)] ease-[var(--ease-out-expo)] group-hover/nav:translate-x-1"
              />
            </Link>
          ) : null}
        </nav>
      </Section>

      <CTASection
        eyebrow="Need a website like this?"
        title={`Want something built the way ${project.name} was?`}
        body="Tell me about your business and what the site needs to do. You will get a fixed written quote for your actual scope."
        secondary={{ href: "/portfolio", label: "More projects" }}
      />
    </>
  );
}
