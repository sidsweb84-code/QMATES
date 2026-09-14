import Link from "next/link";
import type { Metadata } from "next";
import { HomeHero } from "@/components/site/HomeHero";
import { ProjectCard } from "@/components/site/ProjectCard";
import { TestimonialCard } from "@/components/site/TestimonialCard";
import { CTASection } from "@/components/site/CTASection";
import { Section } from "@/components/ui/Section";
import { SectionHeading, Eyebrow } from "@/components/ui/SectionHeading";
import { Reveal, Stagger, StaggerItem } from "@/components/ui/Reveal";
import { ButtonLink } from "@/components/ui/Button";
import { ArrowRight, Check } from "@/components/ui/Icon";
import { previewableProjects } from "@/data/projects";
import { testimonials } from "@/data/testimonials";
import { services, process, principles } from "@/data/services";
import { plans, pricesArePlaceholder } from "@/data/pricing";
import { site } from "@/data/site";

export const metadata: Metadata = {
  title: `${site.name} — ${site.tagline}`,
  description: site.description,
  alternates: { canonical: "/" },
};

export default function HomePage() {
  return (
    <>
      <HomeHero />

      {/* ==================== TRUST ==================== */}
      <Section tone="raised" size="md">
        <div className="grid gap-12 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.15fr)] lg:gap-20">
          <Reveal>
            <Eyebrow className="mb-5">Why QMATES</Eyebrow>
            <h2 className="text-h2 text-bone">
              A website is the first thing a customer{" "}
              <span className="accent-word text-sand">judges</span> you on.
            </h2>
            <p className="mt-6 max-w-md text-lead text-mist">
              Most people decide whether a business is worth contacting before they
              read a single sentence. QMATES exists to make that first few seconds
              work in your favour — then make the next step obvious.
            </p>
          </Reveal>

          <Stagger className="grid gap-px overflow-hidden rounded-[var(--radius-lg)] border border-line bg-line sm:grid-cols-2">
            {principles.map((p) => (
              <StaggerItem key={p.title} className="bg-ink-2 p-6 md:p-7">
                <h3 className="font-display text-[1.0625rem] font-semibold text-bone">
                  {p.title}
                </h3>
                <p className="mt-3 text-meta text-mist">{p.body}</p>
              </StaggerItem>
            ))}
          </Stagger>
        </div>
      </Section>

      {/* ==================== FEATURED WORK ==================== */}
      <Section size="lg">
        <SectionHeading
          eyebrow="01 / Selected work"
          title={
            <>
              Different businesses.
              <br />
              Same attention to detail.
            </>
          }
          lead="Every project starts with what the business actually needs the site to do, then works backwards to the design."
          link={{ href: "/portfolio", label: "All projects" }}
        />

        <div className="mt-14 grid gap-x-8 gap-y-14 md:grid-cols-2 md:gap-y-20">
          {previewableProjects.slice(0, 4).map((project, i) => (
            <Reveal key={project.slug} delay={(i % 2) * 0.08}>
              <ProjectCard project={project} index={i} priority={i < 2} />
            </Reveal>
          ))}
        </div>
      </Section>

      {/* ==================== SERVICES ==================== */}
      <Section tone="raised" size="lg" id="services">
        <SectionHeading
          eyebrow="02 / Services"
          title="What QMATES actually does"
          lead="Six services, all pointed at the same outcome: a site that makes your business easy to trust and easy to contact."
        />

        <Stagger className="rule-t mt-14">
          {services.map((service) => (
            <StaggerItem key={service.id}>
              <div className="group/srv grid gap-4 border-b border-line py-7 transition-colors duration-[var(--duration-base)] hover:bg-surface/40 md:grid-cols-[auto_minmax(0,14rem)_minmax(0,1fr)_auto] md:items-baseline md:gap-8 md:px-4">
                <span className="eyebrow nums text-dim">{service.index}</span>
                <h3 className="text-h3 text-bone transition-transform duration-[var(--duration-slow)] ease-[var(--ease-out-expo)] md:group-hover/srv:translate-x-1">
                  {service.title}
                </h3>
                <p className="text-meta text-mist">{service.summary}</p>
                <div className="flex flex-wrap gap-2 md:justify-end">
                  {service.includes.slice(0, 2).map((inc) => (
                    <span
                      key={inc}
                      className="rounded-[var(--radius-xs)] border border-line px-2 py-1 text-[0.6875rem] whitespace-nowrap text-dim"
                    >
                      {inc}
                    </span>
                  ))}
                </div>
              </div>
            </StaggerItem>
          ))}
        </Stagger>

        <Reveal className="mt-10">
          <ButtonLink href="/about" variant="ghost" withArrow>
            How the work gets done
          </ButtonLink>
        </Reveal>
      </Section>

      {/* ==================== PROCESS ==================== */}
      <Section size="lg">
        <SectionHeading
          eyebrow="03 / Process"
          title="Four steps, no surprises"
          lead="You always know what stage the project is at, what you owe and what happens next."
        />

        <Stagger className="mt-14 grid gap-px overflow-hidden rounded-[var(--radius-lg)] border border-line bg-line md:grid-cols-2 xl:grid-cols-4">
          {process.map((step) => (
            <StaggerItem
              key={step.index}
              className="group/step relative bg-ink p-7 transition-colors duration-[var(--duration-base)] hover:bg-ink-2 md:p-8"
            >
              <span
                aria-hidden="true"
                className="absolute top-0 left-0 h-px w-0 bg-reef transition-[width] duration-[var(--duration-reveal)] ease-[var(--ease-out-expo)] group-hover/step:w-full"
              />
              <p className="eyebrow nums text-reef">{step.index}</p>
              <h3 className="mt-5 text-h3 text-bone">{step.title}</h3>
              <p className="mt-3 text-meta text-mist">{step.body}</p>
              <ul className="mt-6 flex flex-col gap-2">
                {step.detail.map((d) => (
                  <li key={d} className="flex items-start gap-2 text-[0.8125rem] text-dim">
                    <Check size={14} className="mt-0.5 shrink-0 text-reef/70" />
                    {d}
                  </li>
                ))}
              </ul>
            </StaggerItem>
          ))}
        </Stagger>
      </Section>

      {/* ==================== TESTIMONIALS ==================== */}
      <Section tone="raised" size="lg">
        <SectionHeading
          eyebrow="04 / Testimonials"
          title="What clients say"
          lead="These slots are reserved for real client quotes. Nothing here is invented or attributed to anyone who has not said it."
          link={{ href: "/testimonials", label: "View all testimonials" }}
        />

        <Stagger className="mt-14 grid gap-6 md:grid-cols-3">
          {testimonials.slice(0, 3).map((t) => (
            <StaggerItem key={t.id}>
              <TestimonialCard testimonial={t} />
            </StaggerItem>
          ))}
        </Stagger>
      </Section>

      {/* ==================== PRICING PREVIEW ==================== */}
      <Section size="lg">
        <SectionHeading
          eyebrow="05 / Pricing"
          title="Three ways to start"
          lead={
            pricesArePlaceholder
              ? "Figures below are placeholders until final pricing is set. The inclusions are real — request a quote and you get a fixed written figure for your scope."
              : "Fixed pricing, agreed in writing before any work begins."
          }
          link={{ href: "/pricing", label: "Full pricing detail" }}
        />

        <Stagger className="mt-14 grid gap-6 lg:grid-cols-3">
          {plans.map((plan) => (
            <StaggerItem key={plan.id}>
              <div
                className={`flex h-full flex-col rounded-[var(--radius-lg)] border p-7 transition-[border-color,transform] duration-[var(--duration-slow)] ease-[var(--ease-out-expo)] hover:-translate-y-1 ${
                  plan.highlighted
                    ? "border-reef/45 bg-surface"
                    : "border-line bg-ink-2 hover:border-line-strong"
                }`}
              >
                <div className="flex items-start justify-between gap-3">
                  <h3 className="font-display text-h3 text-bone">{plan.name}</h3>
                  {plan.highlighted ? (
                    <span className="eyebrow rounded-[var(--radius-xs)] bg-reef px-2 py-1 text-reef-ink">
                      Most chosen
                    </span>
                  ) : null}
                </div>
                <p className="mt-4 text-meta text-mist">{plan.audience}</p>
                <p className="mt-6 flex items-baseline gap-2">
                  <span className="nums font-display text-[2.25rem] leading-none font-bold text-bone">
                    {plan.price}
                  </span>
                  <span className="text-[0.75rem] text-dim">{plan.priceNote}</span>
                </p>
                <p className="mt-3 text-[0.8125rem] text-dim">
                  {plan.pages} &middot; {plan.timeline}
                </p>
                <ul className="mt-6 flex flex-1 flex-col gap-2.5">
                  {plan.includes.slice(0, 4).map((inc) => (
                    <li key={inc} className="flex items-start gap-2.5 text-[0.8125rem] text-mist">
                      <Check size={15} className="mt-0.5 shrink-0 text-reef" />
                      {inc}
                    </li>
                  ))}
                </ul>
                <Link
                  href="/pricing"
                  className="group/pl mt-7 inline-flex items-center gap-2 border-b border-line pb-1.5 text-meta text-bone transition-colors duration-[var(--duration-base)] hover:border-reef hover:text-reef"
                >
                  See what&apos;s included
                  <ArrowRight
                    size={15}
                    className="transition-transform duration-[var(--duration-base)] ease-[var(--ease-out-expo)] group-hover/pl:translate-x-1 group-hover/pl:-rotate-45"
                  />
                </Link>
              </div>
            </StaggerItem>
          ))}
        </Stagger>
      </Section>

      <CTASection />
    </>
  );
}
