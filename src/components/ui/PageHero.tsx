import type { ReactNode } from "react";
import { cn } from "@/lib/cn";
import { Eyebrow } from "./SectionHeading";
import { Reveal } from "./Reveal";

/**
 * Shared header for every inner page. The index + label row, the oversized
 * title and the aside column give each route a consistent, recognisable
 * opening without repeating the home page hero.
 */
export function PageHero({
  index,
  eyebrow,
  title,
  lead,
  aside,
  children,
}: {
  index: string;
  eyebrow: string;
  title: ReactNode;
  lead?: ReactNode;
  aside?: ReactNode;
  children?: ReactNode;
}) {
  return (
    <header className="grain relative isolate overflow-hidden border-b border-line bg-ink-2">
      <div
        aria-hidden="true"
        className="bloom -top-40 left-1/2 h-[26rem] w-[26rem] -translate-x-1/2 bg-reef/10 md:h-[34rem] md:w-[52rem]"
      />
      <div className="shell relative z-10 pt-32 pb-14 md:pt-40 md:pb-20">
        <Reveal direction="none">
          <div className="flex items-center gap-3">
            <span className="eyebrow nums text-dim">{index}</span>
            <span aria-hidden="true" className="h-px w-8 bg-line-strong" />
            <Eyebrow>{eyebrow}</Eyebrow>
          </div>
        </Reveal>

        <div
          className={cn(
            "mt-8 grid gap-10",
            aside ? "lg:grid-cols-[minmax(0,1.5fr)_minmax(0,1fr)] lg:gap-16" : "",
          )}
        >
          <Reveal delay={0.06}>
            <h1 className="text-hero text-bone">{title}</h1>
            {lead ? <p className="mt-6 max-w-2xl text-lead text-mist">{lead}</p> : null}
          </Reveal>

          {aside ? (
            <Reveal delay={0.14} className="lg:pt-3">
              {aside}
            </Reveal>
          ) : null}
        </div>

        {children ? <div className="mt-10">{children}</div> : null}
      </div>
    </header>
  );
}
