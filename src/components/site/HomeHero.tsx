"use client";

/* ============================================================================
 * HOME HERO
 * ----------------------------------------------------------------------------
 * An animated portfolio stack rather than a laptop mockup: a phone carrying a
 * live-rendered mobile layout sits in front of a desktop browser window, and
 * both step through the featured projects together.
 *
 * The rotation is user-controllable (dots + a pause toggle), pauses on hover
 * and focus, and does not run at all under prefers-reduced-motion.
 * ========================================================================== */

import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { useEffect, useState } from "react";
import { cn } from "@/lib/cn";
import { displayUrl, previewableProjects } from "@/data/projects";
import { ButtonLink } from "@/components/ui/Button";
import { Eyebrow } from "@/components/ui/SectionHeading";
import { ArrowDown, Check } from "@/components/ui/Icon";
import { BrowserFrame, MobileSitePreview, SitePreview } from "./SitePreview";

const ROTATE_MS = 5200;
const stack = previewableProjects.slice(0, 4);

const proofChips = [
  { label: "Hand-coded", note: "No page builders" },
  { label: "Mobile-first", note: "Designed for phones" },
  { label: "Fixed scope", note: "Priced before we start" },
];

export function HomeHero() {
  const reduced = useReducedMotion();
  const [active, setActive] = useState(0);
  const [paused, setPaused] = useState(false);
  /* The pause control is only meaningful once rotation is actually running.
     Gating it on a mounted flag keeps the server and first client render
     identical, which branching on `reduced` directly would not. */
  const [mounted, setMounted] = useState(false);
  const project = stack[active];

  useEffect(() => setMounted(true), []);

  useEffect(() => {
    if (reduced || paused) return;
    const id = window.setInterval(
      () => setActive((i) => (i + 1) % stack.length),
      ROTATE_MS,
    );
    return () => window.clearInterval(id);
  }, [reduced, paused]);

  /* Coordinated entrance — each element follows the one before it.
     Reduction is applied by MotionConfig at animation time. */
  const enter = (i: number) => ({
    initial: { opacity: 0, y: 20 },
    animate: { opacity: 1, y: 0 },
    transition: { duration: 0.75, delay: 0.06 * i, ease: [0.16, 1, 0.3, 1] as const },
  });

  return (
    <section className="grain relative isolate overflow-hidden border-b border-line bg-ink pt-32 pb-16 md:pt-40 md:pb-24">
      <div
        aria-hidden="true"
        className="bloom top-[-10%] right-[-10%] h-[30rem] w-[30rem] bg-reef/12 md:h-[44rem] md:w-[44rem]"
      />
      <div
        aria-hidden="true"
        className="bloom bottom-[-20%] left-[-15%] h-[24rem] w-[24rem] bg-sand/6 md:h-[34rem] md:w-[34rem]"
      />

      <div className="shell relative z-10">
        <div className="grid grid-cols-1 items-center gap-14 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.08fr)] lg:gap-12 xl:gap-16">
          {/* ----------------------------- copy ----------------------------- */}
          <div className="min-w-0">
            <motion.div data-reveal="" {...enter(0)} className="flex items-center gap-3">
              <span className="relative flex size-2">
                <span className="absolute inline-flex size-full animate-ping rounded-full bg-reef opacity-60" />
                <span className="relative inline-flex size-2 rounded-full bg-reef" />
              </span>
              <Eyebrow tone="mist">Queensland&apos;s Online Business Partner</Eyebrow>
            </motion.div>

            <h1 className="mt-7 text-display text-bone">
              <motion.span data-reveal="" {...enter(1)} className="block">
                Websites that
              </motion.span>
              <motion.span data-reveal="" {...enter(2)} className="block">
                make Queensland
              </motion.span>
              <motion.span data-reveal="" {...enter(3)} className="block">
                businesses{" "}
                <span className="accent-word text-reef">impossible</span>
              </motion.span>
              <motion.span data-reveal="" {...enter(4)} className="block">
                to ignore.
              </motion.span>
            </h1>

            <motion.p data-reveal="" {...enter(5)} className="mt-7 max-w-lg text-lead text-mist">
              QMATES designs and builds websites for Queensland businesses — the kind
              that look established, load fast on a phone, and turn a visitor into an
              enquiry instead of a bounce.
            </motion.p>

            <motion.div data-reveal="" {...enter(6)} className="mt-9 flex flex-col gap-3 sm:flex-row">
              <ButtonLink href="/quote" size="lg" withArrow>
                Get a Quote
              </ButtonLink>
              <ButtonLink href="/portfolio" variant="outline" size="lg">
                View My Work
              </ButtonLink>
            </motion.div>

            <motion.ul data-reveal="" {...enter(7)} className="mt-10 flex flex-wrap gap-x-6 gap-y-3">
              {proofChips.map((chip) => (
                <li key={chip.label} className="flex items-center gap-2">
                  <Check size={15} className="shrink-0 text-reef" />
                  <span className="text-meta text-mist">{chip.label}</span>
                  <span className="hidden text-meta text-dim sm:inline">— {chip.note}</span>
                </li>
              ))}
            </motion.ul>
          </div>

          {/* ---------------------------- visual ---------------------------- */}
          <motion.div
            data-reveal=""
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 1, delay: 0.3, ease: [0.16, 1, 0.3, 1] }}
            className="relative min-w-0"
            onMouseEnter={() => setPaused(true)}
            onMouseLeave={() => setPaused(false)}
            onFocusCapture={() => setPaused(true)}
            onBlurCapture={() => setPaused(false)}
          >
            <div className="relative mx-auto flex max-w-xl items-center justify-center pt-6 pb-4 lg:max-w-none">
              {/* desktop window, set back and rotated */}
              <div className="relative w-full max-w-[34rem] rotate-[-2.5deg] lg:-mr-16">
                <AnimatePresence mode="wait">
                  <motion.div
                    key={`browser-${project.slug}`}
                    initial={{ opacity: 0, y: 12 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: -12 }}
                    transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
                  >
                    <BrowserFrame url={displayUrl(project)}>
                      <SitePreview project={project} />
                    </BrowserFrame>
                  </motion.div>
                </AnimatePresence>
              </div>

              {/* phone, front and to the right */}
              <motion.div
                animate={{ y: [0, -10, 0] }}
                transition={{ duration: 7, repeat: Infinity, ease: "easeInOut" }}
                className="absolute right-0 bottom-[-3rem] w-[7.5rem] rotate-[4deg] sm:w-[9.5rem] lg:right-2 lg:bottom-[-3.5rem] lg:w-[13rem]"
              >
                <div
                  aria-hidden="true"
                  className="bloom -inset-8 -z-10 bg-reef/25 blur-[60px]"
                />
                <AnimatePresence mode="wait">
                  <motion.div
                    key={`phone-${project.slug}`}
                    initial={{ opacity: 0, scale: 0.96 }}
                    animate={{ opacity: 1, scale: 1 }}
                    exit={{ opacity: 0, scale: 1.02 }}
                    transition={{ duration: 0.45, ease: [0.16, 1, 0.3, 1] }}
                  >
                    <PhoneShell>
                      <MobileSitePreview project={project} />
                    </PhoneShell>
                  </motion.div>
                </AnimatePresence>
              </motion.div>
            </div>

            {/* --- rotation controls --- */}
            <div className="mt-16 flex items-center justify-between gap-4 lg:mt-20">
              <div className="min-w-0">
                <p className="eyebrow text-dim">Now showing</p>
                <p className="mt-1.5 truncate font-display text-[0.9375rem] font-semibold text-bone">
                  {project.name}
                  <span className="ml-2 font-body text-meta font-normal text-dim">
                    {project.industry}
                  </span>
                </p>
              </div>

              <div className="flex shrink-0 items-center gap-2">
                {stack.map((p, i) => (
                  <button
                    key={p.slug}
                    type="button"
                    onClick={() => setActive(i)}
                    aria-label={`Show ${p.name}`}
                    aria-current={i === active ? "true" : undefined}
                    className={cn(
                      "flex size-9 cursor-pointer items-center justify-center rounded-full border",
                      "text-[0.6875rem] transition-colors duration-[var(--duration-base)]",
                      i === active
                        ? "border-reef bg-reef text-reef-ink"
                        : "border-line text-dim hover:border-line-strong hover:text-mist",
                    )}
                  >
                    <span className="nums">{String(i + 1).padStart(2, "0")}</span>
                  </button>
                ))}
                {mounted && !reduced ? (
                  <button
                    type="button"
                    onClick={() => setPaused((v) => !v)}
                    aria-label={paused ? "Resume preview rotation" : "Pause preview rotation"}
                    className={cn(
                      "ml-1 flex size-9 cursor-pointer items-center justify-center rounded-full",
                      "border border-line text-dim transition-colors duration-[var(--duration-base)]",
                      "hover:border-line-strong hover:text-mist",
                    )}
                  >
                    {paused ? <PlayGlyph /> : <PauseGlyph />}
                  </button>
                ) : null}
              </div>
            </div>
          </motion.div>
        </div>

        {/* --- scroll hint --- */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 1.1, duration: 0.6 }}
          className="mt-20 hidden items-center gap-3 lg:flex"
        >
          <ArrowDown size={16} className="text-reef" />
          <span className="eyebrow text-dim">Scroll for selected work</span>
        </motion.div>
      </div>
    </section>
  );
}

/* A lighter phone bezel tuned for the hero's smaller scale. */
function PhoneShell({ children }: { children: React.ReactNode }) {
  return (
    <div className="relative aspect-[9/19] rounded-[1.6rem] border border-line-strong bg-surface-2 p-[0.3rem] shadow-[var(--shadow-high)]">
      <div className="relative h-full w-full overflow-hidden rounded-[1.35rem] bg-ink">
        <span
          aria-hidden="true"
          className="absolute top-[1.5%] left-1/2 z-10 h-[0.7rem] w-[30%] -translate-x-1/2 rounded-full bg-black"
        />
        {children}
      </div>
    </div>
  );
}

function PauseGlyph() {
  return (
    <span className="flex gap-[3px]" aria-hidden="true">
      <span className="block h-3 w-[2px] rounded-full bg-current" />
      <span className="block h-3 w-[2px] rounded-full bg-current" />
    </span>
  );
}

function PlayGlyph() {
  return (
    <svg width="12" height="12" viewBox="0 0 12 12" aria-hidden="true" focusable="false">
      <path d="M3 1.8 10 6l-7 4.2Z" fill="currentColor" />
    </svg>
  );
}
