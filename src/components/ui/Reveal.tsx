"use client";

/* ============================================================================
 * REVEAL
 * ----------------------------------------------------------------------------
 * Scroll-entry animation used across the site.
 *
 * Two rules this file exists to enforce:
 *
 * 1. NEVER branch the rendered tree on useReducedMotion(). That hook resolves
 *    false during SSR and true after mount, so branching produces a hydration
 *    mismatch for every visitor who has reduced motion enabled. Reduction is
 *    handled by <MotionConfig reducedMotion="user"> in the root layout plus
 *    the CSS guard on [data-reveal] in globals.css, which forces the final
 *    state without any JS involvement.
 *
 * 2. NEVER call motion.create() inside a render. It returns a new component
 *    type on every render, which remounts the whole subtree and drops focus
 *    and state. The cache below creates each tag's component once.
 * ========================================================================== */

import { motion, type Variants } from "motion/react";
import type { ElementType, ReactNode } from "react";

type Direction = "up" | "down" | "left" | "right" | "none";

/* Horizontal offsets are small on purpose: a wide element translated on X
   widens the document until the animation lands. Prefer "up" for full-width
   blocks and keep left/right for narrow columns. */
const offsets: Record<Direction, { x: number; y: number }> = {
  up: { x: 0, y: 28 },
  down: { x: 0, y: -28 },
  left: { x: 20, y: 0 },
  right: { x: -20, y: 0 },
  none: { x: 0, y: 0 },
};

/* One motion component per tag, created once at module scope. */
const cache = new Map<string, ElementType>();
function motionFor(tag: ElementType): ElementType {
  const key = typeof tag === "string" ? tag : "div";
  let made = cache.get(key);
  if (!made) {
    made = motion.create(key) as ElementType;
    cache.set(key, made);
  }
  return made;
}

const EASE = [0.16, 1, 0.3, 1] as const;

export function Reveal({
  children,
  as = "div",
  direction = "up",
  delay = 0,
  className,
  amount = "some",
}: {
  children: ReactNode;
  as?: ElementType;
  direction?: Direction;
  delay?: number;
  className?: string;
  amount?: number | "some" | "all";
}) {
  const Component = motionFor(as);
  const { x, y } = offsets[direction];

  return (
    <Component
      data-reveal=""
      className={className}
      initial={{ opacity: 0, x, y }}
      whileInView={{ opacity: 1, x: 0, y: 0 }}
      viewport={{ once: true, amount }}
      transition={{ duration: 0.72, delay, ease: EASE }}
    >
      {children}
    </Component>
  );
}

const listVariants: Variants = {
  hidden: {},
  shown: { transition: { staggerChildren: 0.07, delayChildren: 0.05 } },
};

const itemVariants: Variants = {
  hidden: { opacity: 0, y: 22 },
  shown: { opacity: 1, y: 0, transition: { duration: 0.62, ease: EASE } },
};

/** Staggered container — pair with <StaggerItem> children. */
export function Stagger({
  children,
  className,
  as = "div",
  amount = "some",
}: {
  children: ReactNode;
  className?: string;
  as?: ElementType;
  amount?: number | "some" | "all";
}) {
  const Component = motionFor(as);
  return (
    <Component
      data-reveal=""
      className={className}
      variants={listVariants}
      initial="hidden"
      whileInView="shown"
      viewport={{ once: true, amount }}
    >
      {children}
    </Component>
  );
}

export function StaggerItem({
  children,
  className,
  as = "div",
}: {
  children: ReactNode;
  className?: string;
  as?: ElementType;
}) {
  const Component = motionFor(as);
  return (
    <Component data-reveal="" className={className} variants={itemVariants}>
      {children}
    </Component>
  );
}
