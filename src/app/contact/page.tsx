import type { Metadata } from "next";
import Link from "next/link";
import { PageHero } from "@/components/ui/PageHero";
import { ContactForm } from "@/components/site/ContactForm";
import { Section } from "@/components/ui/Section";
import { Eyebrow } from "@/components/ui/SectionHeading";
import { Reveal } from "@/components/ui/Reveal";
import { ArrowRight, Mail, MapPin, Phone } from "@/components/ui/Icon";
import { site } from "@/data/site";

export const metadata: Metadata = {
  title: "Contact",
  description:
    "Get in touch with QMATES — email, phone or a short message. For project scoping, use the quote request instead.",
  alternates: { canonical: "/contact" },
  openGraph: {
    title: "Contact — QMATES",
    description: "Get in touch with QMATES about your Queensland business website.",
    url: "/contact",
  },
};

export default function ContactPage() {
  return (
    <>
      <PageHero
        index="07"
        eyebrow="Contact"
        title={
          <>
            Ask anything.
            <br />
            No <span className="accent-word text-reef">pitch</span> attached.
          </>
        }
        lead="For a general question, a second opinion on an existing site, or just to find out whether QMATES is the right fit. Nothing here goes on a mailing list."
      />

      <Section size="lg">
        <div className="grid gap-12 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.5fr)] lg:gap-16">
          {/* --- direct contact --- */}
          <div className="flex flex-col gap-6">
            <Reveal>
              <Eyebrow className="mb-5">Direct</Eyebrow>
              <ul className="flex flex-col gap-px overflow-hidden rounded-[var(--radius-lg)] border border-line bg-line">
                <li>
                  <a
                    href={`mailto:${site.email}`}
                    className="group/c flex items-center gap-4 bg-ink-2 p-5 transition-colors duration-[var(--duration-base)] hover:bg-surface"
                  >
                    <span className="flex size-10 shrink-0 items-center justify-center rounded-[var(--radius-md)] border border-line text-reef">
                      <Mail size={18} />
                    </span>
                    <span className="min-w-0">
                      <span className="eyebrow block text-dim">Email</span>
                      <span className="mt-1 block truncate text-meta text-bone">
                        {site.email}
                      </span>
                    </span>
                    <ArrowRight
                      size={17}
                      className="ml-auto shrink-0 text-dim transition-transform duration-[var(--duration-base)] ease-[var(--ease-out-expo)] group-hover/c:translate-x-1 group-hover/c:-rotate-45 group-hover/c:text-reef"
                    />
                  </a>
                </li>
                <li>
                  <a
                    href={site.phoneHref}
                    className="group/c flex items-center gap-4 bg-ink-2 p-5 transition-colors duration-[var(--duration-base)] hover:bg-surface"
                  >
                    <span className="flex size-10 shrink-0 items-center justify-center rounded-[var(--radius-md)] border border-line text-reef">
                      <Phone size={18} />
                    </span>
                    <span className="min-w-0">
                      <span className="eyebrow block text-dim">Phone</span>
                      <span className="mt-1 block text-meta text-bone">{site.phone}</span>
                    </span>
                    <ArrowRight
                      size={17}
                      className="ml-auto shrink-0 text-dim transition-transform duration-[var(--duration-base)] ease-[var(--ease-out-expo)] group-hover/c:translate-x-1 group-hover/c:-rotate-45 group-hover/c:text-reef"
                    />
                  </a>
                </li>
                <li className="flex items-center gap-4 bg-ink-2 p-5">
                  <span className="flex size-10 shrink-0 items-center justify-center rounded-[var(--radius-md)] border border-line text-reef">
                    <MapPin size={18} />
                  </span>
                  <span>
                    <span className="eyebrow block text-dim">Based in</span>
                    <span className="mt-1 block text-meta text-bone">{site.location}</span>
                  </span>
                </li>
              </ul>
            </Reveal>

            <Reveal delay={0.08} className="rounded-[var(--radius-lg)] border border-line bg-surface/50 p-6">
              <Eyebrow className="mb-3">Hours</Eyebrow>
              <dl className="flex flex-col gap-2 text-meta">
                <div className="flex justify-between gap-4">
                  <dt className="text-mist">Monday – Friday</dt>
                  <dd className="nums text-bone">8:00 – 17:00 AEST</dd>
                </div>
                <div className="flex justify-between gap-4">
                  <dt className="text-mist">Weekends</dt>
                  <dd className="text-dim">Email only</dd>
                </div>
              </dl>
              <p className="mt-4 text-[0.75rem] text-dim">{site.serviceArea}</p>
            </Reveal>

            {/* --- redirect to the conversion path --- */}
            <Reveal delay={0.14}>
              <Link
                href="/quote"
                className="group/q block rounded-[var(--radius-lg)] border border-reef/35 bg-reef/[0.06] p-6 transition-colors duration-[var(--duration-base)] hover:bg-reef/10"
              >
                <Eyebrow className="mb-3">Ready to scope a project?</Eyebrow>
                <p className="text-meta text-mist">
                  The quote request asks the right questions up front, so the first
                  reply you get is a real figure rather than a list of questions.
                </p>
                <span className="mt-4 inline-flex items-center gap-2 text-meta font-medium text-reef">
                  Request a quote instead
                  <ArrowRight
                    size={16}
                    className="transition-transform duration-[var(--duration-base)] ease-[var(--ease-out-expo)] group-hover/q:translate-x-1 group-hover/q:-rotate-45"
                  />
                </span>
              </Link>
            </Reveal>
          </div>

          {/* --- form --- */}
          <Reveal delay={0.08} direction="none">
            <div className="rounded-[var(--radius-lg)] border border-line bg-ink-2 p-6 md:p-9">
              <Eyebrow className="mb-5">Send a message</Eyebrow>
              <ContactForm />
            </div>
          </Reveal>
        </div>
      </Section>
    </>
  );
}
