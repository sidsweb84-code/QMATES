import type { Metadata } from "next";
import Link from "next/link";
import { PageHero } from "@/components/ui/PageHero";
import { TestimonialCard, AwaitingQuote } from "@/components/site/TestimonialCard";
import { CTASection } from "@/components/site/CTASection";
import { Section } from "@/components/ui/Section";
import { Eyebrow } from "@/components/ui/SectionHeading";
import { Reveal, Stagger, StaggerItem } from "@/components/ui/Reveal";
import { ButtonLink } from "@/components/ui/Button";
import { Check } from "@/components/ui/Icon";
import { featuredTestimonial, hasRealTestimonials, testimonials } from "@/data/testimonials";
import { getProject } from "@/data/projects";
import { principles } from "@/data/services";

export const metadata: Metadata = {
  title: "Testimonials",
  description:
    "Client feedback for QMATES. Every quote published here comes from a real client in their own words — nothing is written on their behalf.",
  alternates: { canonical: "/testimonials" },
  openGraph: {
    title: "Testimonials — QMATES",
    description: "Client feedback for QMATES, published only in clients' own words.",
    url: "/testimonials",
  },
};

const rest = testimonials.filter((t) => t.id !== featuredTestimonial.id);
const featuredProject = featuredTestimonial.projectSlug
  ? getProject(featuredTestimonial.projectSlug)
  : undefined;

export default function TestimonialsPage() {
  return (
    <>
      <PageHero
        index="03"
        eyebrow="Testimonials"
        title={
          <>
            Words that have to be
            <br />
            <span className="accent-word text-reef">earned</span>, not written.
          </>
        }
        lead="This page only ever carries quotes that a client has actually given. Until then the slots below stay clearly marked as empty."
      />

      {/* ==================== HONESTY NOTICE ==================== */}
      {!hasRealTestimonials ? (
        <Section size="sm">
          <Reveal className="rounded-[var(--radius-lg)] border border-sand/25 bg-sand/[0.06] p-6 md:p-8">
            <Eyebrow tone="sand" className="mb-3">
              Nothing here is invented
            </Eyebrow>
            <h2 className="max-w-3xl text-h3 text-bone">
              QMATES has no published client testimonials yet.
            </h2>
            <p className="mt-4 max-w-3xl text-meta text-mist">
              Rather than fabricate reviews or attribute words to businesses that
              have never said them, this page shows the structure a real testimonial
              will sit in. Each card describes the kind of feedback that slot is
              reserved for. When a client gives a quote, it goes in verbatim with
              their name, business and — if they give one — their rating.
            </p>
          </Reveal>
        </Section>
      ) : null}

      {/* ==================== FEATURED ==================== */}
      <Section size="lg" tone="raised">
        <Reveal>
          <Eyebrow className="mb-6">Featured</Eyebrow>
          <figure className="relative isolate overflow-hidden rounded-[var(--radius-xl)] border border-line bg-surface p-8 md:p-14">
            <div
              aria-hidden="true"
              className="bloom -top-32 -right-20 h-80 w-80 bg-reef/10"
            />
            <span
              aria-hidden="true"
              className="pointer-events-none absolute top-4 left-6 font-accent text-[9rem] leading-none text-reef/10 select-none md:text-[13rem]"
            >
              &ldquo;
            </span>

            <blockquote className="relative z-10 max-w-3xl">
              <p
                className={
                  featuredTestimonial.isPlaceholder
                    ? "text-[clamp(1.125rem,2.2vw,1.625rem)] leading-snug text-dim italic"
                    : "text-[clamp(1.375rem,3vw,2.25rem)] leading-[1.25] font-medium tracking-[-0.02em] text-bone"
                }
              >
                {featuredTestimonial.isPlaceholder
                  ? featuredTestimonial.quote
                  : `“${featuredTestimonial.quote}”`}
              </p>
            </blockquote>

            <figcaption className="rule-t relative z-10 mt-10 flex flex-wrap items-center justify-between gap-4 pt-6">
              <div>
                {featuredTestimonial.isPlaceholder ? (
                  <AwaitingQuote />
                ) : (
                  <>
                    <p className="font-display text-h3 text-bone">
                      {featuredTestimonial.author}
                    </p>
                    <p className="mt-1 text-meta text-mist">
                      {featuredTestimonial.role}
                      {featuredTestimonial.role && featuredTestimonial.business ? ", " : ""}
                      {featuredTestimonial.business}
                    </p>
                  </>
                )}
                <p className="eyebrow mt-3 text-dim">{featuredTestimonial.businessType}</p>
              </div>
              {featuredProject ? (
                <ButtonLink
                  href={`/portfolio/${featuredProject.slug}`}
                  variant="quiet"
                  size="sm"
                  withArrow
                >
                  {featuredProject.name} case study
                </ButtonLink>
              ) : null}
            </figcaption>
          </figure>
        </Reveal>
      </Section>

      {/* ==================== GRID ==================== */}
      <Section size="lg">
        <Reveal>
          <Eyebrow className="mb-4">More feedback</Eyebrow>
          <h2 className="max-w-2xl text-h2 text-bone">One slot per project</h2>
          <p className="mt-5 max-w-2xl text-meta text-mist">
            Each card is tied to a specific project, so feedback can always be read
            alongside the work it refers to.
          </p>
        </Reveal>

        <Stagger className="mt-12 grid gap-6 md:grid-cols-2 xl:grid-cols-3">
          {rest.map((t) => (
            <StaggerItem key={t.id}>
              <TestimonialCard testimonial={t} />
            </StaggerItem>
          ))}
        </Stagger>
      </Section>

      {/* ==================== WHAT YOU CAN RELY ON ==================== */}
      <Section tone="raised" size="lg">
        <Reveal>
          <Eyebrow className="mb-4">In the meantime</Eyebrow>
          <h2 className="max-w-2xl text-h2 text-bone">
            What you can hold QMATES to <span className="accent-word text-sand">today</span>
          </h2>
          <p className="mt-5 max-w-2xl text-meta text-mist">
            With no reviews to point at yet, these are commitments rather than
            claims — written into every scope before work starts.
          </p>
        </Reveal>

        <Stagger className="mt-12 grid gap-px overflow-hidden rounded-[var(--radius-lg)] border border-line bg-line md:grid-cols-2">
          {principles.map((p) => (
            <StaggerItem key={p.title} className="bg-ink-2 p-7 md:p-8">
              <Check size={18} className="text-reef" />
              <h3 className="mt-4 text-h3 text-bone">{p.title}</h3>
              <p className="mt-3 text-meta text-mist">{p.body}</p>
            </StaggerItem>
          ))}
        </Stagger>

        <Reveal className="mt-10">
          <p className="text-meta text-dim">
            Worked with QMATES and happy to be quoted?{" "}
            <Link
              href="/contact"
              className="text-mist underline decoration-line-strong underline-offset-4 transition-colors duration-[var(--duration-base)] hover:text-reef hover:decoration-reef"
            >
              Send it through
            </Link>{" "}
            and it goes on this page in your words.
          </p>
        </Reveal>
      </Section>

      <CTASection
        eyebrow="Start here"
        title="Be the first testimonial on this page."
        body="Tell me what your business needs and you will get a fixed written quote back."
        secondary={{ href: "/portfolio", label: "See the work first" }}
      />
    </>
  );
}
