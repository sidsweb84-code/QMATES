"use client";

import { MotionConfig } from "motion/react";
import type { ReactNode } from "react";

/**
 * `reducedMotion="user"` makes every Motion animation in the tree skip
 * transform and layout changes when the visitor has reduced motion enabled,
 * decided at animation time rather than render time — so it never causes a
 * hydration mismatch the way branching on useReducedMotion() does.
 */
export function MotionProvider({ children }: { children: ReactNode }) {
  return <MotionConfig reducedMotion="user">{children}</MotionConfig>;
}
