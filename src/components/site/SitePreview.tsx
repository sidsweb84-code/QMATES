/* ============================================================================
 * SITE PREVIEW
 * ----------------------------------------------------------------------------
 * A miniature website rendered entirely in markup and CSS from a project's
 * palette + preview spec. Used for portfolio cards, the gallery, case-study
 * screenshots and the home hero.
 *
 * Why not images: there are no real client screenshots yet. A code-drawn
 * preview is honest (it is a design mockup, not a photograph of a real site),
 * weighs nothing, stays sharp at any size, and never 404s. When real
 * screenshots are supplied, `<Screenshot>` in the case-study template renders
 * those instead and this becomes the fallback.
 *
 * Sizing: the root is a container, and every dimension inside is expressed in
 * container-query width units, so one component scales from a 180px card
 * thumbnail to a full-width hero with identical proportions.
 *
 * The `style` attribute on the root is used only to publish the project's
 * palette as CSS custom properties. All visual rules live in classes.
 * ========================================================================== */

import type { CSSProperties } from "react";
import { cn } from "@/lib/cn";
import type { PreviewLayout, Project } from "@/data/projects";

type PaletteVars = CSSProperties &
  Record<"--p-bg" | "--p-surface" | "--p-ink" | "--p-muted" | "--p-accent" | "--p-accent-ink", string>;

function paletteVars(project: Project): PaletteVars {
  return {
    "--p-bg": project.palette.bg,
    "--p-surface": project.palette.surface,
    "--p-ink": project.palette.ink,
    "--p-muted": project.palette.muted,
    "--p-accent": project.palette.accent,
    "--p-accent-ink": project.palette.accentInk,
  };
}

/* --- shared miniature pieces ---------------------------------------------- */

function MiniNav({ project }: { project: Project }) {
  return (
    <div className="flex items-center justify-between gap-[2cqw] px-[4cqw] py-[2.6cqw]">
      <div className="flex items-center gap-[1.4cqw]">
        <span className="size-[2.2cqw] rounded-[0.4cqw] bg-[var(--p-accent)]" />
        <span className="text-[2.1cqw] font-semibold tracking-tight text-[var(--p-ink)]">
          {project.name}
        </span>
      </div>
      <div className="hidden items-center gap-[2.4cqw] @[22rem]:flex">
        {project.preview.nav.map((item) => (
          <span key={item} className="text-[1.55cqw] text-[var(--p-muted)]">
            {item}
          </span>
        ))}
      </div>
      <span className="rounded-[0.6cqw] bg-[var(--p-accent)] px-[2.2cqw] py-[1cqw] text-[1.5cqw] font-semibold text-[var(--p-accent-ink)]">
        {project.preview.cta}
      </span>
    </div>
  );
}

function MiniButtons({ project, compact = false }: { project: Project; compact?: boolean }) {
  return (
    <div className={cn("flex flex-wrap items-center gap-[1.6cqw]", compact && "gap-[1.2cqw]")}>
      <span className="rounded-[0.6cqw] bg-[var(--p-accent)] px-[3cqw] py-[1.4cqw] text-[1.7cqw] font-semibold text-[var(--p-accent-ink)]">
        {project.preview.cta}
      </span>
      {project.preview.secondaryCta ? (
        <span className="rounded-[0.6cqw] border border-[var(--p-muted)]/35 px-[3cqw] py-[1.4cqw] text-[1.7cqw] text-[var(--p-ink)]">
          {project.preview.secondaryCta}
        </span>
      ) : null}
    </div>
  );
}

function MiniTiles({ project }: { project: Project }) {
  if (!project.preview.tiles?.length) return null;
  return (
    <div className="flex flex-wrap gap-[1.4cqw]">
      {project.preview.tiles.map((tile) => (
        <span
          key={tile}
          className="rounded-[0.5cqw] border border-[var(--p-muted)]/25 bg-[var(--p-surface)] px-[2cqw] py-[1cqw] text-[1.5cqw] text-[var(--p-muted)]"
        >
          {tile}
        </span>
      ))}
    </div>
  );
}

/** Abstract image block — a soft accent field standing in for photography. */
function MiniImage({ className, ratio = "aspect-[4/3]" }: { className?: string; ratio?: string }) {
  return (
    <div
      className={cn(
        "relative overflow-hidden rounded-[1cqw] bg-[var(--p-surface)]",
        ratio,
        className,
      )}
    >
      <span className="absolute -bottom-[30%] left-[10%] size-[80%] rounded-full bg-[var(--p-accent)]/25 blur-[4cqw]" />
      <span className="absolute top-[14%] right-[12%] size-[34%] rounded-full bg-[var(--p-accent)]/40 blur-[3cqw]" />
    </div>
  );
}

function MiniLines({ count = 3, className }: { count?: number; className?: string }) {
  return (
    <div className={cn("flex flex-col gap-[1.1cqw]", className)}>
      {Array.from({ length: count }).map((_, i) => (
        <span
          key={i}
          className={cn(
            "h-[0.9cqw] rounded-full bg-[var(--p-muted)]/25",
            i === count - 1 ? "w-[55%]" : i % 2 === 0 ? "w-full" : "w-[85%]",
          )}
        />
      ))}
    </div>
  );
}

function Headline({ project, size }: { project: Project; size: string }) {
  return (
    <p className={cn("font-semibold tracking-[-0.03em] text-[var(--p-ink)]", size)}>
      {project.preview.headline}
      {project.preview.headlineAccent ? (
        <>
          {" "}
          <span className="text-[var(--p-accent)]">{project.preview.headlineAccent}</span>
        </>
      ) : null}
    </p>
  );
}

/* --- layouts -------------------------------------------------------------- */

function LayoutHero({ project }: { project: Project }) {
  return (
    <>
      <MiniNav project={project} />
      <div className="relative flex-1 px-[4cqw] pb-[4cqw]">
        <MiniImage ratio="aspect-[16/7]" />
        <div className="absolute inset-x-[8cqw] top-[12cqw] flex flex-col gap-[2cqw]">
          <Headline project={project} size="text-[5.4cqw] leading-[0.95] max-w-[70%]" />
          <p className="max-w-[52%] text-[1.75cqw] leading-relaxed text-[var(--p-muted)]">
            {project.preview.sub}
          </p>
          <MiniButtons project={project} />
        </div>
        <div className="mt-[3cqw] flex items-start justify-between gap-[3cqw]">
          <MiniTiles project={project} />
          <MiniLines count={2} className="w-[34%]" />
        </div>
      </div>
    </>
  );
}

function LayoutSplit({ project }: { project: Project }) {
  return (
    <>
      <MiniNav project={project} />
      <div className="flex flex-1 items-center gap-[3.5cqw] px-[4cqw] pb-[4cqw]">
        <div className="flex w-1/2 flex-col gap-[2.2cqw]">
          <Headline project={project} size="text-[4.8cqw] leading-[0.98]" />
          <p className="text-[1.75cqw] leading-relaxed text-[var(--p-muted)]">
            {project.preview.sub}
          </p>
          <MiniButtons project={project} compact />
          <MiniTiles project={project} />
        </div>
        <div className="flex w-1/2 flex-col gap-[1.6cqw]">
          <MiniImage ratio="aspect-[5/4]" />
          <div className="flex gap-[1.6cqw]">
            <MiniImage ratio="aspect-square" className="w-1/2" />
            <MiniImage ratio="aspect-square" className="w-1/2" />
          </div>
        </div>
      </div>
    </>
  );
}

function LayoutEditorial({ project }: { project: Project }) {
  return (
    <>
      <MiniNav project={project} />
      <div className="flex flex-1 flex-col gap-[2.6cqw] px-[4cqw] pb-[4cqw]">
        <div className="flex items-end justify-between gap-[3cqw] border-b border-[var(--p-muted)]/20 pb-[2.4cqw]">
          <Headline project={project} size="text-[6cqw] leading-[0.9] max-w-[64%]" />
          <p className="w-[30%] text-[1.6cqw] leading-relaxed text-[var(--p-muted)]">
            {project.preview.sub}
          </p>
        </div>
        <MiniImage ratio="aspect-[16/6]" />
        <div className="flex items-center justify-between gap-[3cqw]">
          <MiniButtons project={project} compact />
          <MiniTiles project={project} />
        </div>
      </div>
    </>
  );
}

function LayoutGrid({ project }: { project: Project }) {
  return (
    <>
      <MiniNav project={project} />
      <div className="flex flex-1 flex-col gap-[2.4cqw] px-[4cqw] pb-[4cqw]">
        <div className="flex items-end justify-between gap-[3cqw]">
          <Headline project={project} size="text-[4.4cqw] leading-[0.98] max-w-[58%]" />
          <MiniButtons project={project} compact />
        </div>
        <div className="grid flex-1 grid-cols-3 gap-[1.8cqw]">
          {[0, 1, 2].map((i) => (
            <div key={i} className="flex flex-col gap-[1.2cqw]">
              <MiniImage ratio="aspect-[4/5]" />
              <span className="text-[1.6cqw] font-medium text-[var(--p-ink)]">
                {project.preview.tiles?.[i] ?? "Collection"}
              </span>
              <span className="text-[1.4cqw] text-[var(--p-muted)]">From $XX</span>
            </div>
          ))}
        </div>
      </div>
    </>
  );
}

const layouts: Record<PreviewLayout, (p: { project: Project }) => React.JSX.Element> = {
  hero: LayoutHero,
  split: LayoutSplit,
  editorial: LayoutEditorial,
  grid: LayoutGrid,
};

export function SitePreview({
  project,
  layout,
  className,
  aspect = "aspect-[16/10]",
}: {
  project: Project;
  layout?: PreviewLayout;
  className?: string;
  /** Tailwind aspect utility. Passed as a prop rather than merged into
      `className` so two aspect-* classes never compete. */
  aspect?: string;
}) {
  const Layout = layouts[layout ?? project.preview.layout];
  return (
    <div
      style={paletteVars(project)}
      className={cn(
        "@container flex w-full flex-col overflow-hidden bg-[var(--p-bg)]",
        aspect,
        className,
      )}
    >
      <Layout project={project} />
    </div>
  );
}

/* ============================================================================
 * MOBILE PREVIEW + DEVICE FRAMES
 * ========================================================================== */

/** The same project rendered as a phone-shaped layout. */
export function MobileSitePreview({ project }: { project: Project }) {
  return (
    <div
      style={paletteVars(project)}
      className="@container flex h-full w-full flex-col bg-[var(--p-bg)]"
    >
      {/* status bar */}
      <div className="flex items-center justify-between px-[7cqw] pt-[3.5cqw] pb-[1cqw]">
        <span className="text-[3.4cqw] font-semibold text-[var(--p-ink)]">9:41</span>
        <div className="flex items-end gap-[0.8cqw]">
          {[1.6, 2.4, 3.2, 4].map((h) => (
            <span
              key={h}
              className="w-[1cqw] rounded-[0.3cqw] bg-[var(--p-ink)]"
              data-bar={h}
            />
          ))}
          <span className="ml-[1cqw] h-[3cqw] w-[6cqw] rounded-[1cqw] border border-[var(--p-ink)]/60" />
        </div>
      </div>

      {/* app bar */}
      <div className="flex items-center justify-between px-[6cqw] py-[3.5cqw]">
        <div className="flex items-center gap-[2cqw]">
          <span className="size-[4.5cqw] rounded-[1cqw] bg-[var(--p-accent)]" />
          <span className="text-[4cqw] font-semibold tracking-tight text-[var(--p-ink)]">
            {project.name}
          </span>
        </div>
        <div className="flex flex-col gap-[1.2cqw]">
          <span className="h-[0.7cqw] w-[6cqw] rounded-full bg-[var(--p-ink)]/70" />
          <span className="h-[0.7cqw] w-[6cqw] rounded-full bg-[var(--p-ink)]/70" />
        </div>
      </div>

      {/* content */}
      <div className="flex flex-1 flex-col gap-[4cqw] px-[6cqw] pb-[4cqw]">
        <p className="text-[9cqw] leading-[0.95] font-semibold tracking-[-0.035em] text-[var(--p-ink)]">
          {project.preview.headline}
          {project.preview.headlineAccent ? (
            <>
              {" "}
              <span className="text-[var(--p-accent)]">{project.preview.headlineAccent}</span>
            </>
          ) : null}
        </p>
        <p className="text-[3.5cqw] leading-relaxed text-[var(--p-muted)]">
          {project.preview.sub}
        </p>
        <span className="rounded-[1.6cqw] bg-[var(--p-accent)] py-[3.4cqw] text-center text-[3.6cqw] font-semibold text-[var(--p-accent-ink)]">
          {project.preview.cta}
        </span>
        <MiniImage ratio="aspect-[4/3]" className="rounded-[2.5cqw]" />
        <div className="flex flex-wrap gap-[2cqw]">
          {project.preview.tiles?.map((tile) => (
            <span
              key={tile}
              className="rounded-[1.2cqw] border border-[var(--p-muted)]/25 px-[3.2cqw] py-[1.8cqw] text-[3cqw] text-[var(--p-muted)]"
            >
              {tile}
            </span>
          ))}
        </div>
        <MiniLines count={3} />
      </div>

      {/* home indicator */}
      <div className="flex justify-center pb-[2.5cqw]">
        <span className="h-[1cqw] w-[28cqw] rounded-full bg-[var(--p-ink)]/35" />
      </div>
    </div>
  );
}

/**
 * Desktop browser chrome. `url` is shown in the address bar — it is a display
 * string for a mockup, not a link.
 */
export function BrowserFrame({
  children,
  url,
  className,
  tone = "dark",
}: {
  children: React.ReactNode;
  url: string;
  className?: string;
  tone?: "dark" | "light";
}) {
  return (
    <div
      className={cn(
        "overflow-hidden rounded-[var(--radius-lg)] border shadow-[var(--shadow-high)]",
        tone === "dark" ? "border-line-strong bg-surface" : "border-white/15 bg-white/10",
        className,
      )}
    >
      <div className="flex items-center gap-3 border-b border-line bg-surface-2 px-3.5 py-2.5">
        <div className="flex gap-1.5" aria-hidden="true">
          <span className="size-2.5 rounded-full bg-[#ff5f57]" />
          <span className="size-2.5 rounded-full bg-[#febc2e]" />
          <span className="size-2.5 rounded-full bg-[#28c840]" />
        </div>
        <div className="flex min-w-0 flex-1 justify-center">
          <span className="truncate rounded-[var(--radius-sm)] bg-ink/70 px-3 py-1 text-[0.6875rem] text-dim">
            {url}
          </span>
        </div>
        <div className="w-12" aria-hidden="true" />
      </div>
      {children}
    </div>
  );
}

/** Phone bezel with a dynamic-island cutout. */
export function PhoneFrame({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "relative aspect-[9/19] rounded-[2.25rem] border border-line-strong bg-surface-2 p-[0.45rem]",
        "shadow-[var(--shadow-high)]",
        className,
      )}
    >
      {/* side buttons */}
      <span
        aria-hidden="true"
        className="absolute top-[22%] -left-px h-10 w-[2px] rounded-full bg-line-strong"
      />
      <span
        aria-hidden="true"
        className="absolute top-[33%] -right-px h-16 w-[2px] rounded-full bg-line-strong"
      />
      <div className="relative h-full w-full overflow-hidden rounded-[1.85rem] bg-ink">
        <span
          aria-hidden="true"
          className="absolute top-[1.6%] left-1/2 z-10 h-[1.1rem] w-[28%] -translate-x-1/2 rounded-full bg-black"
        />
        {children}
      </div>
    </div>
  );
}
