import type { Metadata } from "next";
import { PageHero } from "@/components/ui/PageHero";
import { CTASection } from "@/components/site/CTASection";
import { FaqList } from "@/components/site/FaqList";
import { Section } from "@/components/ui/Section";
import { Eyebrow } from "@/components/ui/SectionHeading";
import { Reveal, Stagger, StaggerItem } from "@/components/ui/Reveal";
import { ButtonLink } from "@/components/ui/Button";
import { Alert, Check } from "@/components/ui/Icon";
import {
  addOns,
  meetings,
  negotiableNote,
  plans,
  pricingFaqs,
} from "@/data/pricing";
import { cn } from "@/lib/cn";

export const metadata: Metadata = {
  title: "Pricing",
  description:
    "QMATES website pricing — Booster from $300, Starter from $400, and a customised growth plan quoted per business. Real figures, listed plainly.",
  alternates: { canonical: "/pricing" },
  openGraph: {
    title: "Pricing — QMATES",
    description: "Website pricing for Queensland businesses. Real figures, listed plainly.",
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
            Three plans.
            <br />
            Priced <span className="accent-word text-reef">plainly</span>.
          </>
        }
        lead="Real figures, not headline numbers designed to get you on the phone. Everything outside a plan is listed further down at what it actually costs."
      />

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
                  <span className="nums font-display text-[clamp(2.125rem,2.6vw,2.75rem)] leading-none font-bold whitespace-nowrap text-bone">
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
                    <dt className="eyebrow text-dim">Support</dt>
                    <dd className="mt-1.5 text-[0.8125rem] text-mist">{plan.support}</dd>
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

                {plan.excludes?.length ? (
                  <ul className="rule-t mt-6 flex flex-col gap-2 pt-5">
                    {plan.excludes.map((ex) => (
                      <li
                        key={ex}
                        className="flex items-start gap-2.5 text-[0.8125rem] text-sand"
                      >
                        <Alert size={15} className="mt-0.5 shrink-0" />
                        {ex}
                      </li>
                    ))}
                  </ul>
                ) : null}

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

      {/* ==================== NEGOTIABLE NOTE ==================== */}
      <Section size="sm">
        <Reveal className="flex items-start gap-3 rounded-[var(--radius-lg)] border border-line bg-surface/50 p-6 md:p-7">
          <Alert size={18} className="mt-0.5 shrink-0 text-sand" />
          <p className="max-w-3xl text-meta text-mist">{negotiableNote}</p>
        </Reveal>
      </Section>

      {/* ==================== ADD-ONS ==================== */}
      <Section tone="raised" size="lg">
        <Reveal>
          <Eyebrow className="mb-4">Add-ons</Eyebrow>
          <h2 className="max-w-2xl text-h2 text-bone">Everything outside a plan</h2>
          <p className="mt-5 max-w-2xl text-meta text-mist">
            Added only if you want them, and always agreed before any work starts.
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

      {/* ==================== MEETINGS ==================== */}
      <Section size="lg">
        <Reveal>
          <Eyebrow className="mb-4">Meetings and discussion</Eyebrow>
          <h2 className="max-w-2xl text-h2 text-bone">
            How we actually <span className="accent-word text-sand">talk</span> it through
          </h2>
          <p className="mt-5 max-w-2xl text-meta text-mist">
            Scope gets agreed in a conversation, not a form. Where that happens
            depends on where you are.
          </p>
        </Reveal>

        <Stagger className="mt-12 grid gap-px overflow-hidden rounded-[var(--radius-lg)] border border-line bg-line md:grid-cols-2">
          {meetings.map((m, i) => (
            <StaggerItem key={m.title} className="bg-ink-2 p-7 md:p-9">
              <p className="eyebrow nums text-reef">
                {String(i + 1).padStart(2, "0")}
              </p>
              <h3 className="mt-5 text-h3 text-bone">{m.title}</h3>
              <p className="eyebrow mt-3 text-dim">{m.who}</p>
              <p className="mt-4 text-meta text-mist">{m.body}</p>
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
