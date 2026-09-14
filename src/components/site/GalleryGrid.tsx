"use client";

/* ============================================================================
 * GALLERY
 * Asymmetric grid of every screen across every project, filterable by
 * industry, with a lightbox for a closer look. Each lightbox entry links
 * through to the full case study so the gallery is never a dead end.
 * ========================================================================== */

import Link from "next/link";
import { AnimatePresence,  motion } from "motion/react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { cn } from "@/lib/cn";
import { projects, type PreviewLayout, type Project, type ProjectCategory } from "@/data/projects";
import { ArrowLeft, ArrowRight, ArrowUpRight, Close, Expand } from "@/components/ui/Icon";
import { BrowserFrame, SitePreview } from "./SitePreview";

type Shot = {
  id: string;
  project: Project;
  layout: PreviewLayout;
  caption: string;
  category: ProjectCategory;
};

/* Every project contributes its home screen plus each gallery screen. */
const allShots: Shot[] = projects.flatMap((project) => [
  {
    id: `${project.slug}-home`,
    project,
    layout: project.preview.layout,
    caption: "Home page",
    category: project.category,
  },
  ...project.gallery.map((g, i) => ({
    id: `${project.slug}-${i}`,
    project,
    layout: g.layout,
    caption: g.caption,
    category: project.category,
  })),
]);

const categories: ("All" | ProjectCategory)[] = [
  "All",
  ...([...new Set(projects.map((p) => p.category))] as ProjectCategory[]),
];

/* A repeating rhythm of preview heights so the masonry columns stagger
   rather than lining up as a uniform card grid. */
const aspects = [
  "aspect-[16/10]",
  "aspect-[16/9]",
  "aspect-[4/3]",
  "aspect-[16/11]",
  "aspect-[3/2]",
  "aspect-[16/10]",
];

export function GalleryGrid() {
  const [filter, setFilter] = useState<"All" | ProjectCategory>("All");
  const [openIndex, setOpenIndex] = useState<number | null>(null);
  const closeRef = useRef<HTMLButtonElement>(null);
  const lastTrigger = useRef<HTMLElement | null>(null);

  const shots = useMemo(
    () => (filter === "All" ? allShots : allShots.filter((s) => s.category === filter)),
    [filter],
  );

  const close = useCallback(() => {
    setOpenIndex(null);
    lastTrigger.current?.focus();
  }, []);

  const step = useCallback(
    (dir: 1 | -1) =>
      setOpenIndex((i) => (i === null ? i : (i + dir + shots.length) % shots.length)),
    [shots.length],
  );

  /* Lightbox: scroll lock, Escape to close, arrow keys to move. */
  useEffect(() => {
    if (openIndex === null) return;
    const { overflow } = document.body.style;
    document.body.style.overflow = "hidden";

    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") close();
      if (e.key === "ArrowRight") step(1);
      if (e.key === "ArrowLeft") step(-1);
    };
    document.addEventListener("keydown", onKey);
    closeRef.current?.focus();

    return () => {
      document.body.style.overflow = overflow;
      document.removeEventListener("keydown", onKey);
    };
  }, [openIndex, close, step]);

  const open = shots[openIndex ?? -1];

  return (
    <>
      {/* --- filters --- */}
      <div className="flex flex-wrap items-center gap-2" role="group" aria-label="Filter gallery by industry">
        {categories.map((c) => {
          const active = filter === c;
          const count = c === "All" ? allShots.length : allShots.filter((s) => s.category === c).length;
          return (
            <button
              key={c}
              type="button"
              onClick={() => {
                setFilter(c);
                setOpenIndex(null);
              }}
              aria-pressed={active}
              className={cn(
                "inline-flex min-h-10 cursor-pointer items-center gap-2 rounded-[var(--radius-md)] border px-3.5",
                "text-[0.8125rem] transition-colors duration-[var(--duration-base)]",
                active
                  ? "border-reef bg-reef text-reef-ink"
                  : "border-line bg-surface/50 text-mist hover:border-line-strong hover:text-bone",
              )}
            >
              {c}
              <span className={cn("nums text-[0.6875rem]", active ? "text-reef-ink/70" : "text-dim")}>
                {count}
              </span>
            </button>
          );
        })}
      </div>

      {/* --- grid --- */}
      <ul className="mt-10 gap-5 sm:columns-2 xl:columns-3">
        <AnimatePresence initial={false}>
          {shots.map((shot, i) => (
            <motion.li
              key={shot.id}
              initial={{ opacity: 0, y: 14 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0 }}
              transition={{
                duration: 0.45,
                delay: Math.min(i, 8) * 0.04,
                ease: [0.16, 1, 0.3, 1],
              }}
              className="mb-5 break-inside-avoid"
            >
              <button
                type="button"
                onClick={(e) => {
                  lastTrigger.current = e.currentTarget;
                  setOpenIndex(i);
                }}
                aria-label={`Open ${shot.project.name} — ${shot.caption}`}
                className={cn(
                  "group/g block w-full cursor-pointer overflow-hidden rounded-[var(--radius-lg)]",
                  "border border-line bg-surface text-left transition-[border-color,transform,box-shadow]",
                  "duration-[var(--duration-slow)] ease-[var(--ease-out-expo)]",
                  "hover:-translate-y-1 hover:border-line-strong hover:shadow-[var(--shadow-high)]",
                )}
              >
                <span className="relative block overflow-hidden">
                  <SitePreview
                    project={shot.project}
                    layout={shot.layout}
                    aspect={aspects[i % aspects.length]}
                    className="transition-transform duration-[900ms] ease-[var(--ease-out-expo)] group-hover/g:scale-[1.04]"
                  />
                  <span
                    aria-hidden="true"
                    className={cn(
                      "pointer-events-none absolute inset-0 flex items-center justify-center",
                      "bg-black/45 opacity-0 transition-opacity duration-[var(--duration-base)]",
                      "group-hover/g:opacity-100",
                    )}
                  >
                    <span className="flex size-11 items-center justify-center rounded-full bg-reef text-reef-ink">
                      <Expand size={18} />
                    </span>
                  </span>
                </span>
                <span className="flex items-center justify-between gap-3 px-4 py-3.5">
                  <span className="min-w-0">
                    <span className="block truncate font-display text-[0.9375rem] font-semibold text-bone">
                      {shot.project.name}
                    </span>
                    <span className="mt-0.5 block truncate text-[0.75rem] text-dim">
                      {shot.caption}
                    </span>
                  </span>
                  <span className="eyebrow shrink-0 text-dim">{shot.category}</span>
                </span>
              </button>
            </motion.li>
          ))}
        </AnimatePresence>
      </ul>

      {/* --- lightbox --- */}
      <AnimatePresence>
        {open ? (
          <motion.div
            role="dialog"
            aria-modal="true"
            aria-label={`${open.project.name} — ${open.caption}`}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.24 }}
            className="fixed inset-0 z-[60] flex flex-col bg-ink/95 backdrop-blur-xl"
          >
            {/* backdrop click target */}
            <button
              type="button"
              aria-label="Close preview"
              tabIndex={-1}
              onClick={close}
              className="absolute inset-0 cursor-zoom-out"
            />

            <div className="relative z-10 flex items-center justify-between gap-4 border-b border-line px-4 py-3 md:px-6">
              <div className="min-w-0">
                <p className="truncate font-display text-[0.9375rem] font-semibold text-bone">
                  {open.project.name}
                </p>
                <p className="truncate text-[0.75rem] text-dim">{open.caption}</p>
              </div>
              <div className="flex shrink-0 items-center gap-2">
                <span className="nums hidden text-[0.75rem] text-dim sm:block">
                  {(openIndex ?? 0) + 1} / {shots.length}
                </span>
                <button
                  type="button"
                  onClick={() => step(-1)}
                  aria-label="Previous screen"
                  className="flex size-10 cursor-pointer items-center justify-center rounded-[var(--radius-md)] border border-line text-mist transition-colors duration-[var(--duration-base)] hover:border-line-strong hover:text-bone"
                >
                  <ArrowLeft size={17} />
                </button>
                <button
                  type="button"
                  onClick={() => step(1)}
                  aria-label="Next screen"
                  className="flex size-10 cursor-pointer items-center justify-center rounded-[var(--radius-md)] border border-line text-mist transition-colors duration-[var(--duration-base)] hover:border-line-strong hover:text-bone"
                >
                  <ArrowRight size={17} />
                </button>
                <button
                  ref={closeRef}
                  type="button"
                  onClick={close}
                  aria-label="Close preview"
                  className="flex size-10 cursor-pointer items-center justify-center rounded-[var(--radius-md)] border border-line text-mist transition-colors duration-[var(--duration-base)] hover:border-reef hover:text-reef"
                >
                  <Close size={17} />
                </button>
              </div>
            </div>

            <div className="relative z-10 flex flex-1 items-center justify-center overflow-y-auto p-4 md:p-8">
              <motion.div
                key={open.id}
                initial={{ opacity: 0, scale: 0.98 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ duration: 0.32, ease: [0.16, 1, 0.3, 1] }}
                className="w-full max-w-5xl"
              >
                <BrowserFrame url={`${open.project.slug}.com.au`}>
                  <SitePreview project={open.project} layout={open.layout} />
                </BrowserFrame>
                <div className="mt-5 flex flex-wrap items-center justify-between gap-4">
                  <p className="max-w-xl text-meta text-mist">{open.project.summary}</p>
                  <Link
                    href={`/portfolio/${open.project.slug}`}
                    className="group/lb inline-flex min-h-11 items-center gap-2 rounded-[var(--radius-md)] bg-reef px-5 text-[0.875rem] font-semibold text-reef-ink"
                  >
                    View case study
                    <ArrowUpRight
                      size={16}
                      className="transition-transform duration-[var(--duration-base)] group-hover/lb:translate-x-0.5 group-hover/lb:-translate-y-0.5"
                    />
                  </Link>
                </div>
              </motion.div>
            </div>
          </motion.div>
        ) : null}
      </AnimatePresence>
    </>
  );
}
