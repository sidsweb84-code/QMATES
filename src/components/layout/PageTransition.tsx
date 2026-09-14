"use client";

/* ============================================================================
 * PAGE TRANSITION
 * Each route change re-keys this wrapper, so the incoming page fades and
 * lifts into place. Enter-only by design: exit animations in the App Router
 * hold the outgoing tree in the DOM and cause a visible scroll jump.
 *
 * Reduction is handled by MotionConfig + the [data-reveal] CSS guard, never
 * by branching the tree — see the note in Reveal.tsx.
 * ========================================================================== */

import { motion } from "motion/react";
import { usePathname } from "next/navigation";
import type { ReactNode } from "react";

export function PageTransition({ children }: { children: ReactNode }) {
  const pathname = usePathname();

  return (
    <motion.div
      key={pathname}
      data-reveal=""
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.42, ease: [0.16, 1, 0.3, 1] }}
    >
      {children}
    </motion.div>
  );
}
