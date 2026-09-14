import type { Metadata } from "next";
import { ButtonLink } from "@/components/ui/Button";
import { Eyebrow } from "@/components/ui/SectionHeading";
import { navItems } from "@/data/site";
import Link from "next/link";
import { ArrowRight } from "@/components/ui/Icon";

export const metadata: Metadata = {
  title: "Page not found",
  robots: { index: false, follow: true },
};

export default function NotFound() {
  return (
    <section className="grain relative isolate flex min-h-dvh items-center overflow-hidden bg-ink pt-32 pb-20">
      <div
        aria-hidden="true"
        className="bloom top-1/4 left-1/2 h-80 w-[30rem] -translate-x-1/2 bg-reef/10"
      />
      <div className="shell relative z-10">
        <Eyebrow className="mb-6">Error 404</Eyebrow>
        <p className="nums font-display text-[clamp(4rem,16vw,11rem)] leading-[0.85] font-bold tracking-[-0.05em] text-bone">
          404
        </p>
        <h1 className="mt-8 max-w-2xl text-h2 text-bone">
          That page does not exist — or it has moved.
        </h1>
        <p className="mt-5 max-w-xl text-lead text-mist">
          Check the address, or pick up from one of the pages below.
        </p>

        <div className="mt-10 flex flex-col gap-3 sm:flex-row">
          <ButtonLink href="/" size="lg" withArrow>
            Back to home
          </ButtonLink>
          <ButtonLink href="/portfolio" variant="outline" size="lg">
            View the work
          </ButtonLink>
        </div>

        <nav aria-label="All pages" className="rule-t mt-16 pt-8">
          <Eyebrow className="mb-5 text-dim">All pages</Eyebrow>
          <ul className="flex flex-wrap gap-x-8 gap-y-3">
            {[...navItems, { label: "Get a Quote", href: "/quote" }].map((item) => (
              <li key={item.href}>
                <Link
                  href={item.href}
                  className="group/nf inline-flex min-h-9 items-center gap-1.5 text-meta text-mist transition-colors duration-[var(--duration-base)] hover:text-reef"
                >
                  {item.label}
                  <ArrowRight
                    size={14}
                    className="transition-transform duration-[var(--duration-base)] group-hover/nf:translate-x-1 group-hover/nf:-rotate-45"
                  />
                </Link>
              </li>
            ))}
          </ul>
        </nav>
      </div>
    </section>
  );
}
