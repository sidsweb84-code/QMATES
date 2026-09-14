import { ButtonLink } from "@/components/ui/Button";
import { Eyebrow } from "@/components/ui/SectionHeading";
import { Reveal } from "@/components/ui/Reveal";
import { site } from "@/data/site";

/**
 * The closing conversion block. Appears at the foot of every page with a
 * page-specific headline so it never reads as boilerplate.
 */
export function CTASection({
  eyebrow = "Next step",
  title = "Ready to give your business a better online presence?",
  body = "Tell me what your business does and what you need the site to achieve. You will get a fixed written quote back — no obligation, no sales call unless you want one.",
  primary = { href: "/quote", label: "Get a Quote" },
  secondary = { href: "/portfolio", label: "See the work" },
}: {
  eyebrow?: string;
  title?: string;
  body?: string;
  primary?: { href: string; label: string };
  secondary?: { href: string; label: string } | null;
}) {
  return (
    <section className="grain relative isolate overflow-hidden border-t border-line bg-ink-2 py-24 md:py-32">
      <div
        aria-hidden="true"
        className="bloom top-1/2 left-1/2 h-80 w-[34rem] -translate-x-1/2 -translate-y-1/2 bg-reef/12 md:w-[56rem]"
      />
      <div className="shell relative z-10">
        <Reveal className="mx-auto max-w-3xl text-center">
          <Eyebrow className="mb-5">{eyebrow}</Eyebrow>
          <h2 className="text-h2 text-bone">{title}</h2>
          <p className="mx-auto mt-6 max-w-xl text-lead text-mist">{body}</p>

          <div className="mt-10 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <ButtonLink href={primary.href} size="lg" withArrow>
              {primary.label}
            </ButtonLink>
            {secondary ? (
              <ButtonLink href={secondary.href} variant="outline" size="lg">
                {secondary.label}
              </ButtonLink>
            ) : null}
          </div>

          <p className="mt-8 text-meta text-dim">
            Prefer to talk first?{" "}
            <a
              href={`mailto:${site.email}`}
              className="text-mist underline decoration-line-strong underline-offset-4 transition-colors duration-[var(--duration-base)] hover:text-reef hover:decoration-reef"
            >
              {site.email}
            </a>
          </p>
        </Reveal>
      </div>
    </section>
  );
}
