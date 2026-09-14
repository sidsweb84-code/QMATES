import Link from "next/link";
import { cn } from "@/lib/cn";
import { STATUS_LABEL, type Project } from "@/data/projects";
import { ArrowRight } from "@/components/ui/Icon";
import { SitePreview } from "./SitePreview";

export function StatusTag({
  project,
  className,
}: {
  project: Project;
  className?: string;
}) {
  const isReal = project.status !== "sample";
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 rounded-[var(--radius-xs)] border px-2 py-1",
        "text-[0.625rem] font-medium tracking-[0.12em] uppercase",
        isReal
          ? "border-reef/35 bg-reef/10 text-reef"
          : "border-sand/35 bg-sand/10 text-sand",
        className,
      )}
    >
      <span
        aria-hidden="true"
        className={cn("size-1 rounded-full", isReal ? "bg-reef" : "bg-sand")}
      />
      {STATUS_LABEL[project.status]}
    </span>
  );
}

/**
 * Portfolio card. Hover composes four coordinated movements: the preview
 * scales, a scrim lifts, the title shifts right and the arrow rotates.
 * The whole card is one link, so the target is large and the tab stop single.
 */
export function ProjectCard({
  project,
  index,
  className,
  priority = false,
}: {
  project: Project;
  index: number;
  className?: string;
  priority?: boolean;
}) {
  return (
    <article className={className}>
      <Link
        href={`/portfolio/${project.slug}`}
        className="group/card block focus-visible:outline-offset-8"
        aria-label={`View the ${project.name} case study`}
      >
        {/* --- header row --- */}
        <div className="mb-3 flex items-end justify-between gap-4 border-b border-line pb-2.5">
          <span className="eyebrow nums text-dim">
            {String(index + 1).padStart(2, "0")} &mdash; {project.category}
          </span>
          <span className="eyebrow truncate text-dim">
            {project.liveLabel ?? project.location}
          </span>
        </div>

        {/* --- preview --- */}
        <div
          className={cn(
            "relative overflow-hidden rounded-[var(--radius-lg)] border border-line bg-surface",
            "transition-[border-color,transform,box-shadow] duration-[var(--duration-slow)]",
            "ease-[var(--ease-out-expo)] group-hover/card:-translate-y-1.5",
            "group-hover/card:border-line-strong group-hover/card:shadow-[var(--shadow-high)]",
          )}
        >
          <div className="overflow-hidden">
            <SitePreview
              project={project}
              className={cn(
                "transition-transform duration-[900ms] ease-[var(--ease-out-expo)]",
                "group-hover/card:scale-[1.035]",
              )}
            />
          </div>

          {/* scrim + reveal row */}
          <div
            aria-hidden="true"
            className={cn(
              "pointer-events-none absolute inset-x-0 bottom-0 flex items-end justify-between gap-4 p-5",
              "translate-y-2 bg-linear-to-t from-black/85 via-black/45 to-transparent pt-16 opacity-0",
              "transition-[opacity,transform] duration-[var(--duration-slow)] ease-[var(--ease-out-expo)]",
              "group-hover/card:translate-y-0 group-hover/card:opacity-100",
            )}
          >
            <span className="text-meta font-medium text-white">View case study</span>
            <span className="flex size-9 items-center justify-center rounded-full bg-reef text-reef-ink">
              <ArrowRight size={16} className="-rotate-45" />
            </span>
          </div>
        </div>

        {/* --- meta --- */}
        <div className="mt-6 flex items-start justify-between gap-6">
          <div className="min-w-0">
            <h3
              className={cn(
                "text-h3 text-bone transition-transform duration-[var(--duration-slow)]",
                "ease-[var(--ease-out-expo)] group-hover/card:translate-x-1",
              )}
            >
              {project.name}
            </h3>
            <p className="mt-2 text-meta text-mist">{project.summary}</p>
          </div>
          <div className="hidden shrink-0 text-right sm:block">
            <p className="eyebrow nums text-dim">{project.year}</p>
            {project.pages > 0 ? (
              <p className="eyebrow nums mt-2 text-dim/80">{project.pages} pages</p>
            ) : null}
          </div>
        </div>

        <div className="mt-4 flex flex-wrap items-center gap-2">
          <StatusTag project={project} />
          {project.services.slice(0, 3).map((s) => (
            <span
              key={s}
              className="rounded-[var(--radius-xs)] border border-line px-2 py-1 text-[0.6875rem] text-dim"
            >
              {s}
            </span>
          ))}
        </div>
      </Link>
    </article>
  );
}
