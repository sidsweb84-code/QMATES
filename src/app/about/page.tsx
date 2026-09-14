import type { Metadata } from "next";
import { PageHero } from "@/components/ui/PageHero";
import { CTASection } from "@/components/site/CTASection";
import { Section } from "@/components/ui/Section";
import { Eyebrow } from "@/components/ui/SectionHeading";
import { Reveal, Stagger, StaggerItem } from "@/components/ui/Reveal";
import { ButtonLink } from "@/components/ui/Button";
import { Check } from "@/components/ui/Icon";
import { PhoneFrame, MobileSitePreview } from "@/components/site/SitePreview";
import { principles, process, services } from "@/data/services";
import { featuredProjects } from "@/data/projects";
import { site } from "@/data/site";

export const metadata: Metadata = {
  title: "About",
  description:
    "QMATES is a one-person web design studio working with Queensland businesses. Fixed scope, fixed price, and you talk directly to the person building the site.",
  alternates: { canonical: "/about" },
  openGraph: {
    title: "About — QMATES",
    description: "A one-person web design studio for Queensland businesses.",
    url: "/about",
  },
};

const worksWith = [
  {
    title: "Trades and service businesses",
    body: "Solar, mechanical, electrical, landscaping — businesses where the site has to prove you are real, cover the right suburbs and make booking easy.",
  },
  {
    title: "Hospitality and retail",
    body: "Venues and shops where the menu, the hours and the booking link are the only three things most visitors came for.",
  },
  {
    title: "Professional practices",
    body: "Legal, health and advisory practices where credibility and a low-pressure first contact matter more than visual fireworks.",
  },
  {
    title: "Businesses with a site that is not working",
    body: "You already have a website. It looks dated, loads slowly, or nobody ever enquires through it.",
  },
];

export default function AboutPage() {
  return (
    <>
      <PageHero
        index="06"
        eyebrow="About"
        title={
          <>
            A web designer,
            <br />
            not a <span className="accent-word text-reef">web builder</span>.
          </>
        }
        lead="QMATES is a one-person studio. The person you brief is the person who designs it, writes the code and hands it over. There is no account manager in between and nothing gets outsourced."
      />

      {/* ==================== THE POSITION ==================== */}
      <Section size="lg">
        <div className="grid gap-14 lg:grid-cols-[minmax(0,1.5fr)_minmax(0,1fr)] lg:gap-20">
          <Reveal>
            <Eyebrow className="mb-5">What QMATES is</Eyebrow>
            <div className="flex max-w-2xl flex-col gap-6 text-lead text-mist">
              <p>
                Most small businesses in Queensland end up with one of two websites.
                Either a template picked off a builder, filled with someone else&apos;s
                stock photos and copy that could belong to any business in the
                country — or a site a relative built once, years ago, that nobody has
                touched since.
              </p>
              <p>
                Both cost you the same thing: a customer who had every intention of
                enquiring, decided in about four seconds that you looked smaller or
                less established than you are, and went back to the search results.
              </p>
              <p className="text-bone">
                QMATES exists to close that gap. Every site is designed for the
                specific business, built by hand, and pointed at a single outcome —
                making it obvious that you are worth contacting, and making the
                contacting easy.
              </p>
            </div>
          </Reveal>

          <Reveal delay={0.1} className="flex justify-center lg:justify-end">
            <PhoneFrame className="w-[14rem] sm:w-[16rem]">
              <MobileSitePreview project={featuredProjects[0]} />
            </PhoneFrame>
          </Reveal>
        </div>
      </Section>

      {/* ==================== PHILOSOPHY ==================== */}
      <Section tone="raised" size="lg">
        <Reveal>
          <Eyebrow className="mb-4">The philosophy</Eyebrow>
          <h2 className="max-w-3xl text-h2 text-bone">
            A website is a <span className="accent-word text-sand">sales tool</span>,
            not a brochure
          </h2>
          <p className="mt-6 max-w-2xl text-lead text-mist">
            Looking good is the minimum, not the goal. Every decision — the layout,
            what goes above the fold, how many fields the form asks for — is made
            against one question: does this make it more likely someone gets in
            touch?
          </p>
        </Reveal>

        <Stagger className="mt-14 grid gap-px overflow-hidden rounded-[var(--radius-lg)] border border-line bg-line md:grid-cols-2">
          {principles.map((p, i) => (
            <StaggerItem key={p.title} className="bg-ink-2 p-7 md:p-9">
              <span className="eyebrow nums text-reef">
                {String(i + 1).padStart(2, "0")}
              </span>
              <h3 className="mt-4 text-h3 text-bone">{p.title}</h3>
              <p className="mt-3 text-meta text-mist">{p.body}</p>
            </StaggerItem>
          ))}
        </Stagger>
      </Section>

      {/* ==================== DIFFERENCE ==================== */}
      <Section size="lg">
        <Reveal>
          <Eyebrow className="mb-4">What makes it different</Eyebrow>
          <h2 className="max-w-2xl text-h2 text-bone">Three things worth knowing</h2>
        </Reveal>

        <Stagger className="rule-t mt-12">
          {[
            {
              n: "01",
              t: "Nothing is built on a page builder",
              b: "No WordPress theme, no drag-and-drop plugin stack. Sites are written by hand, which is why they load fast and do not break the week a plugin updates itself.",
            },
            {
              n: "02",
              t: "Mobile is designed, not shrunk",
              b: "The phone layout gets its own design pass. It is not the desktop layout squeezed until it fits — which is what most template sites give you.",
            },
            {
              n: "03",
              t: "Accessibility is built in, not bolted on",
              b: "Proper contrast, full keyboard operation, real labels and text that survives being scaled up. It is better for every visitor, and it is how the site should have been built anyway.",
            },
          ].map((item) => (
            <StaggerItem key={item.n}>
              <div className="grid gap-3 border-b border-line py-8 md:grid-cols-[auto_minmax(0,18rem)_minmax(0,1fr)] md:gap-10">
                <span className="eyebrow nums text-reef">{item.n}</span>
                <h3 className="text-h3 text-bone">{item.t}</h3>
                <p className="text-meta text-mist">{item.b}</p>
              </div>
            </StaggerItem>
          ))}
        </Stagger>
      </Section>

      {/* ==================== WHO ==================== */}
      <Section tone="raised" size="lg">
        <Reveal>
          <Eyebrow className="mb-4">Who QMATES works with</Eyebrow>
          <h2 className="max-w-2xl text-h2 text-bone">
            Queensland businesses that need to look the part
          </h2>
          <p className="mt-5 max-w-2xl text-meta text-mist">{site.serviceArea}</p>
        </Reveal>

        <Stagger className="mt-12 grid gap-6 md:grid-cols-2">
          {worksWith.map((w) => (
            <StaggerItem
              key={w.title}
              className="rounded-[var(--radius-lg)] border border-line bg-ink-2 p-7 transition-[border-color,transform] duration-[var(--duration-slow)] ease-[var(--ease-out-expo)] hover:-translate-y-1 hover:border-line-strong"
            >
              <Check size={18} className="text-reef" />
              <h3 className="mt-4 text-h3 text-bone">{w.title}</h3>
              <p className="mt-3 text-meta text-mist">{w.body}</p>
            </StaggerItem>
          ))}
        </Stagger>
      </Section>

      {/* ==================== PROCESS ==================== */}
      <Section size="lg">
        <Reveal>
          <Eyebrow className="mb-4">The process</Eyebrow>
          <h2 className="max-w-2xl text-h2 text-bone">
            How a project actually <span className="accent-word text-reef">runs</span>
          </h2>
        </Reveal>

        <Stagger className="mt-12 grid gap-px overflow-hidden rounded-[var(--radius-lg)] border border-line bg-line md:grid-cols-2 xl:grid-cols-4">
          {process.map((step) => (
            <StaggerItem key={step.index} className="bg-ink p-7 md:p-8">
              <p className="eyebrow nums text-reef">{step.index}</p>
              <h3 className="mt-5 text-h3 text-bone">{step.title}</h3>
              <p className="mt-3 text-meta text-mist">{step.body}</p>
              <ul className="rule-t mt-6 flex flex-col gap-2 pt-5">
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

        <Reveal className="mt-12 flex flex-col gap-3 sm:flex-row">
          <ButtonLink href="/pricing" variant="outline" withArrow>
            What it costs
          </ButtonLink>
          <ButtonLink href="/portfolio" variant="ghost" withArrow>
            See the work
          </ButtonLink>
        </Reveal>
      </Section>

      {/* ==================== SERVICES SUMMARY ==================== */}
      <Section tone="raised" size="md">
        <Reveal>
          <Eyebrow className="mb-4">Everything offered</Eyebrow>
          <h2 className="max-w-2xl text-h2 text-bone">Six services</h2>
        </Reveal>
        <Stagger className="mt-10 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {services.map((s) => (
            <StaggerItem
              key={s.id}
              className="rounded-[var(--radius-md)] border border-line bg-ink-2 p-5"
            >
              <span className="eyebrow nums text-dim">{s.index}</span>
              <h3 className="mt-3 font-display text-[1.0625rem] font-semibold text-bone">
                {s.title}
              </h3>
              <p className="mt-2 text-[0.8125rem] text-mist">{s.detail}</p>
            </StaggerItem>
          ))}
        </Stagger>
      </Section>

      <CTASection
        eyebrow="Work together"
        title="Sound like the right fit?"
        body="Tell me about the business and what the site needs to do. You will get a fixed written quote back — no obligation."
        secondary={{ href: "/contact", label: "Ask something first" }}
      />
    </>
  );
}
