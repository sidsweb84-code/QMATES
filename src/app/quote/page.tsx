import type { Metadata } from "next";
import { PageHero } from "@/components/ui/PageHero";
import { QuoteForm } from "@/components/site/QuoteForm";
import { Section } from "@/components/ui/Section";
import { Eyebrow } from "@/components/ui/SectionHeading";
import { Reveal } from "@/components/ui/Reveal";
import { Check, Mail, Phone } from "@/components/ui/Icon";
import { site } from "@/data/site";
import { process } from "@/data/services";

export const metadata: Metadata = {
  title: "Request a Quote",
  description:
    "Request a fixed written quote for a website from QMATES. Two minutes, no obligation, and no sales call unless you ask for one.",
  alternates: { canonical: "/quote" },
  openGraph: {
    title: "Request a Quote — QMATES",
    description: "Get a fixed written quote for your Queensland business website.",
    url: "/quote",
  },
};

const assurances = [
  "A fixed written figure, not a range",
  "No obligation and no sales call unless you want one",
  "A reply within two business days",
  "Your details are never passed to anyone else",
];

export default function QuotePage() {
  return (
    <>
      <PageHero
        index="05"
        eyebrow="Request a quote"
        title={
          <>
            Tell me what you need.
            <br />
            Get a <span className="accent-word text-reef">real</span> number.
          </>
        }
        lead="Three short steps. The more you can tell me about the business and what the site has to achieve, the more accurate the quote comes back."
      />

      <Section size="lg">
        <div className="grid gap-12 lg:grid-cols-[minmax(0,1.7fr)_minmax(0,1fr)] lg:gap-16">
          {/* --- form --- */}
          <Reveal direction="none">
            <QuoteForm />
          </Reveal>

          {/* --- reassurance rail --- */}
          <Reveal delay={0.1} className="lg:sticky lg:top-28 lg:self-start">
            <div className="rounded-[var(--radius-lg)] border border-line bg-surface/50 p-6 md:p-7">
              <Eyebrow className="mb-5">What you get back</Eyebrow>
              <ul className="flex flex-col gap-3.5">
                {assurances.map((a) => (
                  <li key={a} className="flex items-start gap-2.5 text-meta text-mist">
                    <Check size={16} className="mt-0.5 shrink-0 text-reef" />
                    {a}
                  </li>
                ))}
              </ul>

              <div className="rule-t mt-7 pt-6">
                <Eyebrow className="mb-4">Then what happens</Eyebrow>
                <ol className="flex flex-col gap-4">
                  {process.map((step) => (
                    <li key={step.index} className="flex gap-3.5">
                      <span className="eyebrow nums shrink-0 pt-0.5 text-reef">
                        {step.index}
                      </span>
                      <span>
                        <span className="block text-[0.875rem] font-medium text-bone">
                          {step.title}
                        </span>
                        <span className="mt-1 block text-[0.8125rem] text-dim">
                          {step.body}
                        </span>
                      </span>
                    </li>
                  ))}
                </ol>
              </div>

              <div className="rule-t mt-7 pt-6">
                <Eyebrow className="mb-4">Rather just talk?</Eyebrow>
                <div className="flex flex-col gap-2.5">
                  <a
                    href={`mailto:${site.email}`}
                    className="inline-flex min-h-9 items-center gap-2.5 text-meta text-mist transition-colors duration-[var(--duration-base)] hover:text-reef"
                  >
                    <Mail size={16} className="shrink-0 text-dim" />
                    <span className="[overflow-wrap:anywhere]">{site.email}</span>
                  </a>
                  <a
                    href={site.phoneHref}
                    className="inline-flex min-h-9 items-center gap-2.5 text-meta text-mist transition-colors duration-[var(--duration-base)] hover:text-reef"
                  >
                    <Phone size={16} className="shrink-0 text-dim" />
                    {site.phone}
                  </a>
                </div>
              </div>
            </div>
          </Reveal>
        </div>
      </Section>
    </>
  );
}
