import Link from "next/link";
import { navItems, site } from "@/data/site";
import { ArrowUpRight, Mail, MapPin, Phone } from "@/components/ui/Icon";
import { cn } from "@/lib/cn";

const columns = [
  { title: "Pages", items: navItems.slice(0, 4) },
  { title: "More", items: [...navItems.slice(4), { label: "Get a Quote", href: "/quote" }] },
];

export function Footer() {
  const year = new Date().getFullYear();

  return (
    <footer className="grain relative isolate overflow-hidden border-t border-line bg-ink-2">
      <div
        aria-hidden="true"
        className="bloom -bottom-56 left-1/2 h-96 w-[42rem] -translate-x-1/2 bg-reef/8"
      />

      <div className="shell relative z-10 pt-20 pb-10 md:pt-24">
        <div className="grid gap-12 lg:grid-cols-[minmax(0,1.4fr)_minmax(0,1fr)] lg:gap-20">
          {/* --- brand block --- */}
          <div>
            <p className="font-display text-[clamp(2.5rem,7vw,4.5rem)] leading-[0.9] font-bold tracking-[-0.05em] text-bone">
              {site.name}
            </p>
            <p className="mt-4 max-w-sm text-lead text-mist">{site.tagline}</p>

            <div className="mt-8 inline-flex items-center gap-2.5 rounded-[var(--radius-sm)] border border-line bg-surface/60 px-3.5 py-2">
              <span className="relative flex size-2">
                <span className="absolute inline-flex size-full animate-ping rounded-full bg-positive opacity-60" />
                <span className="relative inline-flex size-2 rounded-full bg-positive" />
              </span>
              <span className="eyebrow text-mist">{site.availability}</span>
            </div>
          </div>

          {/* --- link columns + contact --- */}
          <div className="grid gap-10 sm:grid-cols-3">
            {columns.map((col) => (
              <nav key={col.title} aria-label={col.title}>
                <p className="eyebrow mb-5 text-dim">{col.title}</p>
                <ul className="flex flex-col gap-3">
                  {col.items.map((item) => (
                    <li key={item.href}>
                      <Link
                        href={item.href}
                        className={cn(
                          "group/fl inline-flex min-h-6 items-center gap-1.5 py-0.5 text-meta text-mist",
                          "transition-colors duration-[var(--duration-base)] hover:text-reef",
                        )}
                      >
                        <span className="relative">
                          {item.label}
                          <span
                            aria-hidden="true"
                            className="absolute -bottom-0.5 left-0 h-px w-full origin-left scale-x-0 bg-reef transition-transform duration-[var(--duration-base)] ease-[var(--ease-out-expo)] group-hover/fl:scale-x-100"
                          />
                        </span>
                      </Link>
                    </li>
                  ))}
                </ul>
              </nav>
            ))}

            <div>
              <p className="eyebrow mb-5 text-dim">Contact</p>
              <ul className="flex flex-col gap-3">
                <li>
                  <a
                    href={`mailto:${site.email}`}
                    className="inline-flex min-h-6 items-center gap-2 py-0.5 text-meta text-mist transition-colors duration-[var(--duration-base)] hover:text-reef"
                  >
                    <Mail size={15} className="shrink-0 text-dim" />
                    <span className="[overflow-wrap:anywhere]">{site.email}</span>
                  </a>
                </li>
                <li>
                  <a
                    href={site.phoneHref}
                    className="inline-flex min-h-6 items-center gap-2 py-0.5 text-meta text-mist transition-colors duration-[var(--duration-base)] hover:text-reef"
                  >
                    <Phone size={15} className="shrink-0 text-dim" />
                    {site.phone}
                  </a>
                </li>
                <li className="inline-flex min-h-6 items-center gap-2 py-0.5 text-meta text-mist">
                  <MapPin size={15} className="shrink-0 text-dim" />
                  {site.location}
                </li>
              </ul>

              <p className="eyebrow mt-8 mb-4 text-dim">Social</p>
              <ul className="flex flex-col gap-3">
                {site.socials.map((s) =>
                  s.href ? (
                    <li key={s.label}>
                      <a
                        href={s.href}
                        target="_blank"
                        rel="noreferrer noopener"
                        className="group/so inline-flex min-h-6 items-center gap-1.5 py-0.5 text-meta text-mist transition-colors duration-[var(--duration-base)] hover:text-reef"
                      >
                        {s.label}
                        <ArrowUpRight
                          size={13}
                          className="transition-transform duration-[var(--duration-base)] group-hover/so:translate-x-0.5 group-hover/so:-translate-y-0.5"
                        />
                      </a>
                    </li>
                  ) : (
                    /* No URL supplied yet — rendered as text rather than a dead link. */
                    <li key={s.label} className="text-meta text-dim">
                      {s.label} <span className="text-dim/70">— link to be added</span>
                    </li>
                  ),
                )}
              </ul>
            </div>
          </div>
        </div>

        {/* --- baseline --- */}
        <div className="rule-t mt-16 flex flex-col gap-3 pt-6 sm:flex-row sm:items-center sm:justify-between">
          <p className="text-[0.75rem] text-dim">
            &copy; {year} {site.name}. {site.tagline}.
            {site.abn ? <span className="ml-2">ABN {site.abn}</span> : null}
          </p>
          <p className="text-[0.75rem] text-dim">
            Designed &amp; built in Queensland.
          </p>
        </div>
      </div>
    </footer>
  );
}
