import type { Metadata } from "next";
import { PageHero } from "@/components/ui/PageHero";
import { CTASection } from "@/components/site/CTASection";
import { FaqList } from "@/components/site/FaqList";
import { Section } from "@/components/ui/Section";
import { Eyebrow } from "@/components/ui/SectionHeading";
import { Reveal, Stagger, StaggerItem } from "@/components/ui/Reveal";
import { ButtonLink } from "@/components/ui/Button";
import { Check } from "@/components/ui/Icon";
import { addOns, plans, pricesArePlaceholder, pricingFaqs } from "@/data/pricing";
import { process } from "@/data/services";
import { cn } from "@/lib/cn";

export const metadata: Metadata = {
  title: "Pricing",
  description:
    "QMATES website packages — Starter, Growth and Custom. Fixed scope, fixed price, agreed in writing before any work begins.",
  alternates: { canonical: "/pricing" },
  openGraph: {
    title: "Pricing — QMATES",
    description: "Website packages for Queensland businesses. Fixed scope, fixed price.",
    url: "/pricing",
  },
};

export default function PricingPage() {
  return (
    <>
      <PageHero
        index="04"
        eyebrow="Pricing"
        title={
          <>
            Fixed scope.
            <br />
            Fixed <span className="accent-word text-reef">price</span>.
          </>
        }
        lead="You get a written scope and a firm figure before anything starts. If the scope changes, you approve the change first — there is no open-ended hourly meter."
      />

      {/* ==================== PLACEHOLDER NOTICE ==================== */}
      {pricesArePlaceholder ? (
        <Section size="sm">
          <Reveal className="rounded-[var(--radius-lg)] border border-sand/25 bg-sand/[0.06] p-6 md:p-8">
            <Eyebrow tone="sand" className="mb-3">
              About the figures below
            </Eyebrow>
            <p className="max-w-3xl text-meta text-mist">
              Package prices are shown as{" "}
              <strong className="font-semibold text-bone">$XXX placeholders</strong>{" "}
              because final pricing has not been set in this build. Everything else
              on this page — inclusions, page counts, timelines — is real. Request a
              quote and you will get a fixed written figure for your actual scope.
            </p>
          </Reveal>
        </Section>
      ) : null}

      {/* ==================== PLANS ==================== */}
      <Section size="lg">
        <Stagger className="grid gap-6 lg:grid-cols-3 lg:items-start">
          {plans.map((plan) => (
            <StaggerItem key={plan.id}>
              <article
                className={cn(
                  "relative flex h-full flex-col rounded-[var(--radius-lg)] border p-7 md:p-8",
                  "transition-[border-color,transform] duration-[var(--duration-slow)] ease-[var(--ease-out-expo)]",
                  plan.highlighted
                    ? "border-reef/45 bg-surface shadow-[var(--shadow-mid)] lg:-mt-4 lg:pb-11"
                    : "border-line bg-ink-2 hover:-translate-y-1 hover:border-line-strong",
                )}
              >
                {plan.highlighted ? (
                  <span className="eyebrow absolute -top-3 left-7 rounded-[var(--radius-xs)] bg-reef px-2.5 py-1.5 text-reef-ink">
                    Most chosen
                  </span>
                ) : null}

                <h2 className="font-display text-h3 text-bone">{plan.name}</h2>
                <p className="mt-3 text-meta text-mist">{plan.audience}</p>

                <p className="mt-7 flex items-baseline gap-2">
                  <span className="nums font-display text-[2.75rem] leading-none font-bold text-bone">
                    {plan.price}
                  </span>
                  <span className="text-[0.8125rem] text-dim">{plan.priceNote}</span>
                </p>

                <dl className="rule-t mt-6 grid grid-cols-2 gap-4 pt-5">
                  <div>
                    <dt className="eyebrow text-dim">Scope</dt>
                    <dd className="mt-1.5 text-[0.8125rem] text-mist">{plan.pages}</dd>
                  </div>
                  <div>
                    <dt className="eyebrow text-dim">Timeline</dt>
                    <dd className="mt-1.5 text-[0.8125rem] text-mist">{plan.timeline}</dd>
                  </div>
                </dl>

                <p className="mt-6 text-meta text-mist">{plan.description}</p>

                <p className="eyebrow mt-8 mb-4 text-dim">What&apos;s included</p>
                <ul className="flex flex-1 flex-col gap-3">
                  {plan.includes.map((inc) => (
                    <li key={inc} className="flex items-start gap-2.5 text-[0.875rem] text-mist">
                      <Check size={16} className="mt-0.5 shrink-0 text-reef" />
                      {inc}
                    </li>
                  ))}
                </ul>

                <ButtonLink
                  href="/quote"
                  variant={plan.highlighted ? "solid" : "outline"}
                  size="md"
                  withArrow
                  className="mt-8 w-full"
                >
                  {plan.cta}
                </ButtonLink>
              </article>
            </StaggerItem>
          ))}
        </Stagger>
      </Section>

      {/* ==================== ADD-ONS ==================== */}
      <Section tone="raised" size="lg">
        <Reveal>
          <Eyebrow className="mb-4">Add-ons</Eyebrow>
          <h2 className="max-w-2xl text-h2 text-bone">Extras, priced separately</h2>
          <p className="mt-5 max-w-2xl text-meta text-mist">
            Added only if you want them, and always quoted before they are built.
          </p>
        </Reveal>

        <Stagger className="rule-t mt-12">
          {addOns.map((a) => (
            <StaggerItem key={a.name}>
              <div className="flex flex-col gap-2 border-b border-line py-6 md:flex-row md:items-baseline md:justify-between md:gap-8">
                <div className="md:w-64 md:shrink-0">
                  <h3 className="font-display text-[1.0625rem] font-semibold text-bone">
                    {a.name}
                  </h3>
                </div>
                <p className="flex-1 text-meta text-mist">{a.note}</p>
                <p className="nums font-display text-[1.25rem] font-bold text-reef md:w-24 md:text-right">
                  {a.price}
                </p>
              </div>
            </StaggerItem>
          ))}
        </Stagger>
      </Section>

      {/* ==================== WHAT HAPPENS ==================== */}
      <Section size="lg">
        <Reveal>
          <Eyebrow className="mb-4">What you are paying for</Eyebrow>
          <h2 className="max-w-2xl text-h2 text-bone">
            Four stages, all included in the figure
          </h2>
        </Reveal>

        <Stagger className="mt-12 grid gap-px overflow-hidden rounded-[var(--radius-lg)] border border-line bg-line md:grid-cols-2 xl:grid-cols-4">
          {process.map((step) => (
            <StaggerItem key={step.index} className="bg-ink-2 p-7">
              <p className="eyebrow nums text-reef">{step.index}</p>
              <h3 className="mt-4 text-h3 text-bone">{step.title}</h3>
              <p className="mt-3 text-meta text-mist">{step.body}</p>
            </StaggerItem>
          ))}
        </Stagger>
      </Section>

      {/* ==================== FAQ ==================== */}
      <Section tone="raised" size="lg">
        <div className="grid gap-12 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.6fr)] lg:gap-20">
          <Reveal className="lg:sticky lg:top-28 lg:self-start">
            <Eyebrow className="mb-4">Questions</Eyebrow>
            <h2 className="text-h2 text-bone">
              The things people ask <span className="accent-word text-sand">first</span>
            </h2>
          </Reveal>
          <Reveal delay={0.08}>
            <FaqList items={pricingFaqs} idPrefix="pricing-faq" />
          </Reveal>
        </div>
      </Section>

      <CTASection
        eyebrow="Get a figure"
        title="Want a real number instead of a package?"
        body="Send through your scope and you will get a fixed written quote for your specific project."
        secondary={{ href: "/contact", label: "Ask a question first" }}
      />
    </>
  );
}
