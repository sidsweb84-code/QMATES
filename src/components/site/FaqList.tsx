"use client";

/* Accessible disclosure list. Uses native <details> semantics via buttons so
   the open state can animate, with aria-expanded/aria-controls wiring. */

import { AnimatePresence,  motion } from "motion/react";
import { useState } from "react";
import { cn } from "@/lib/cn";
import type { Faq } from "@/data/pricing";
import { Minus, Plus } from "@/components/ui/Icon";

export function FaqList({ items, idPrefix = "faq" }: { items: Faq[]; idPrefix?: string }) {
  const [open, setOpen] = useState<number | null>(0);

  return (
    <ul className="rule-t">
      {items.map((item, i) => {
        const isOpen = open === i;
        return (
          <li key={item.q} className="border-b border-line">
            <h3>
              <button
                type="button"
                onClick={() => setOpen(isOpen ? null : i)}
                aria-expanded={isOpen}
                aria-controls={`${idPrefix}-panel-${i}`}
                id={`${idPrefix}-button-${i}`}
                className={cn(
                  "group/faq flex w-full cursor-pointer items-center justify-between gap-6 py-5 text-left",
                  "transition-colors duration-[var(--duration-base)] hover:text-reef",
                  isOpen ? "text-reef" : "text-bone",
                )}
              >
                <span className="font-display text-[1.0625rem] font-semibold md:text-[1.1875rem]">
                  {item.q}
                </span>
                <span
                  className={cn(
                    "flex size-8 shrink-0 items-center justify-center rounded-full border",
                    "transition-colors duration-[var(--duration-base)]",
                    isOpen ? "border-reef text-reef" : "border-line text-mist group-hover/faq:border-line-strong",
                  )}
                >
                  {isOpen ? <Minus size={15} /> : <Plus size={15} />}
                </span>
              </button>
            </h3>

            <AnimatePresence initial={false}>
              {isOpen ? (
                <motion.div
                  id={`${idPrefix}-panel-${i}`}
                  role="region"
                  aria-labelledby={`${idPrefix}-button-${i}`}
                  initial={{ height: 0, opacity: 0 }}
                  animate={{ height: "auto", opacity: 1 }}
                  exit={{ height: 0, opacity: 0 }}
                  transition={{ duration: 0.34, ease: [0.16, 1, 0.3, 1] }}
                  className="overflow-hidden"
                >
                  <p className="max-w-2xl pb-6 text-meta text-mist">{item.a}</p>
                </motion.div>
              ) : null}
            </AnimatePresence>
          </li>
        );
      })}
    </ul>
  );
}
