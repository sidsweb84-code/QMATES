import Link from "next/link";
import type { ReactNode } from "react";
import { cn } from "@/lib/cn";
import { ArrowRight } from "./Icon";
import { Reveal } from "./Reveal";

export function Eyebrow({
  children,
  className,
  tone = "reef",
}: {
  children: ReactNode;
  className?: string;
  tone?: "reef" | "sand" | "mist";
}) {
  const tones = { reef: "text-reef", sand: "text-sand", mist: "text-dim" };
  return <p className={cn("eyebrow", tones[tone], className)}>{children}</p>;
}

/**
 * Section header with an optional trailing link. The heading and the link sit
 * on a shared baseline rule, echoing the editorial reference layouts.
 */
export function SectionHeading({
  eyebrow,
  title,
  lead,
  link,
  className,
  align = "start",
}: {
  eyebrow?: string;
  title: ReactNode;
  lead?: ReactNode;
  link?: { href: string; label: string };
  className?: string;
  align?: "start" | "center";
}) {
  return (
    <Reveal
      className={cn(
        "flex flex-col gap-6 md:flex-row md:items-end md:justify-between",
        align === "center" && "md:flex-col md:items-center md:text-center",
        className,
      )}
    >
      <div className={cn("max-w-2xl", align === "center" && "md:mx-auto")}>
        {eyebrow ? <Eyebrow className="mb-4">{eyebrow}</Eyebrow> : null}
        <h2 className="text-h2 text-bone">{title}</h2>
        {lead ? <p className="mt-5 text-lead text-mist">{lead}</p> : null}
      </div>

      {link ? (
        <Link
          href={link.href}
          className={cn(
            "group/sl hl inline-flex shrink-0 items-center gap-2 border-b border-line pb-1.5",
            "text-meta text-bone transition-colors duration-[var(--duration-base)]",
            "hover:border-reef hover:text-reef md:pb-2",
          )}
        >
          <span aria-hidden="true" className="hl-bg" />
          {link.label}
          <ArrowRight
            size={16}
            className="transition-transform duration-[var(--duration-base)] ease-[var(--ease-out-expo)] group-hover/sl:translate-x-1 group-hover/sl:-rotate-45"
          />
        </Link>
      ) : null}
    </Reveal>
  );
}
