"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { AnimatePresence,  motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { cn } from "@/lib/cn";
import { navItems, site } from "@/data/site";
import { ArrowRight, Logo } from "@/components/ui/Icon";

/** True when `href` is the current route (or an ancestor of it). */
function isActive(pathname: string, href: string) {
  if (href === "/") return pathname === "/";
  return pathname === href || pathname.startsWith(`${href}/`);
}

export function Navbar() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const panelRef = useRef<HTMLDivElement>(null);
  const toggleRef = useRef<HTMLButtonElement>(null);

  /* Condense the bar once the page has moved off the top. */
  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 24);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  /* Close the mobile panel whenever the route changes. */
  useEffect(() => {
    setOpen(false);
  }, [pathname]);

  /* While the panel is open: lock scroll, trap Escape, restore focus. */
  useEffect(() => {
    if (!open) return;
    const { overflow } = document.body.style;
    document.body.style.overflow = "hidden";

    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        setOpen(false);
        toggleRef.current?.focus();
      }
    };
    document.addEventListener("keydown", onKey);

    // Move focus into the panel so keyboard users land inside it.
    panelRef.current?.focus();

    return () => {
      document.body.style.overflow = overflow;
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  return (
    <>
      <a
        href="#main"
        className={cn(
          "sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4 focus:z-[100]",
          "focus:rounded-[var(--radius-md)] focus:bg-reef focus:px-4 focus:py-3",
          "focus:text-sm focus:font-semibold focus:text-reef-ink",
        )}
      >
        Skip to main content
      </a>

      <header
        className={cn(
          "fixed inset-x-0 top-0 z-50 transition-[background-color,border-color,backdrop-filter,padding]",
          "duration-[var(--duration-slow)] ease-[var(--ease-out-expo)]",
          scrolled || open
            ? "border-b border-line bg-ink/85 py-2.5 backdrop-blur-xl"
            : "border-b border-transparent py-4",
        )}
      >
        <nav className="shell flex items-center justify-between gap-4" aria-label="Primary">
          {/* --- brand --- */}
          <Link
            href="/"
            className="group/brand flex shrink-0 items-center gap-2.5"
            aria-label={`${site.name} — home`}
          >
            <Logo
              size={26}
              className="text-bone transition-transform duration-[var(--duration-slow)] ease-[var(--ease-out-expo)] group-hover/brand:rotate-[-18deg]"
            />
            <span className="flex flex-col leading-none">
              <span className="font-display text-[1.0625rem] font-bold tracking-[-0.03em] text-bone">
                {site.name}
              </span>
              <span className="eyebrow mt-1 hidden text-[0.5625rem] text-dim sm:block">
                Queensland
              </span>
            </span>
          </Link>

          {/* --- desktop links --- */}
          <ul className="hidden items-center gap-0.5 rounded-[var(--radius-xl)] border border-line bg-surface/60 p-1 backdrop-blur-sm lg:flex">
            {navItems.map((item) => {
              const active = isActive(pathname, item.href);
              return (
                <li key={item.href} className="relative">
                  <Link
                    href={item.href}
                    aria-current={active ? "page" : undefined}
                    className={cn(
                      "relative z-10 block rounded-[var(--radius-lg)] px-3.5 py-2 text-[0.8125rem]",
                      "transition-colors duration-[var(--duration-base)]",
                      active ? "text-reef-ink" : "text-mist hover:text-bone",
                    )}
                  >
                    {item.label}
                  </Link>
                  {active ? (
                    <motion.span
                      aria-hidden="true"
                      layoutId="nav-active"
                      className="absolute inset-0 rounded-[var(--radius-lg)] bg-reef"
                      transition={{ type: "spring", stiffness: 420, damping: 34 }}
                    />
                  ) : null}
                </li>
              );
            })}
          </ul>

          {/* --- right side --- */}
          <div className="flex shrink-0 items-center gap-2">
            <Link
              href="/quote"
              className={cn(
                "group/cta relative hidden items-center gap-2 overflow-hidden rounded-[var(--radius-md)]",
                "border border-reef/60 px-4 py-2.5 text-[0.8125rem] font-semibold text-reef",
                "transition-colors duration-[var(--duration-base)] hover:text-reef-ink sm:inline-flex",
              )}
            >
              <span
                aria-hidden="true"
                className="absolute inset-0 -z-10 origin-left scale-x-0 bg-reef transition-transform duration-[var(--duration-base)] ease-[var(--ease-out-expo)] group-hover/cta:scale-x-100"
              />
              Get a Quote
              <ArrowRight
                size={15}
                className="transition-transform duration-[var(--duration-base)] ease-[var(--ease-out-expo)] group-hover/cta:translate-x-0.5 group-hover/cta:-rotate-45"
              />
            </Link>

            {/* --- hamburger --- */}
            <button
              ref={toggleRef}
              type="button"
              onClick={() => setOpen((v) => !v)}
              aria-expanded={open}
              aria-controls="mobile-nav"
              aria-label={open ? "Close menu" : "Open menu"}
              className={cn(
                "flex size-11 cursor-pointer items-center justify-center rounded-[var(--radius-md)]",
                "border border-line bg-surface/70 text-bone transition-colors",
                "duration-[var(--duration-base)] hover:border-line-strong lg:hidden",
              )}
            >
              <span className="relative block h-3 w-5" aria-hidden="true">
                <span
                  className={cn(
                    "absolute left-0 block h-px w-5 bg-current transition-all",
                    "duration-[var(--duration-base)] ease-[var(--ease-out-expo)]",
                    open ? "top-1.5 rotate-45" : "top-0",
                  )}
                />
                <span
                  className={cn(
                    "absolute left-0 block h-px bg-current transition-all",
                    "duration-[var(--duration-base)] ease-[var(--ease-out-expo)]",
                    open ? "top-1.5 w-5 -rotate-45" : "top-3 w-3.5",
                  )}
                />
              </span>
            </button>
          </div>
        </nav>
      </header>

      {/* --- mobile panel --- */}
      <AnimatePresence>
        {open ? (
          <motion.div
            id="mobile-nav"
            ref={panelRef}
            tabIndex={-1}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.24, ease: [0.16, 1, 0.3, 1] }}
            className="fixed inset-0 z-40 flex flex-col bg-ink/97 pt-24 backdrop-blur-2xl outline-none lg:hidden"
          >
            <div className="shell flex flex-1 flex-col overflow-y-auto pb-10">
              <ul className="flex flex-col">
                {navItems.map((item, i) => {
                  const active = isActive(pathname, item.href);
                  return (
                    <motion.li
                      key={item.href}
                      initial={{ opacity: 0, y: 16 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: 0.04 + i * 0.045, duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
                      className="rule-t"
                    >
                      <Link
                        href={item.href}
                        aria-current={active ? "page" : undefined}
                        className={cn(
                          "group/ml flex items-baseline justify-between gap-4 py-5",
                          active ? "text-reef" : "text-bone",
                        )}
                      >
                        <span className="font-display text-[1.75rem] font-semibold tracking-[-0.03em]">
                          {item.label}
                        </span>
                        <span className="eyebrow nums text-dim">
                          {String(i + 1).padStart(2, "0")}
                        </span>
                      </Link>
                    </motion.li>
                  );
                })}
              </ul>

              <motion.div
                initial={{ opacity: 0, y: 16 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.38, duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
                className="mt-auto pt-10"
              >
                <Link
                  href="/quote"
                  className="flex min-h-14 items-center justify-between gap-3 rounded-[var(--radius-md)] bg-reef px-6 font-semibold text-reef-ink"
                >
                  Get a Quote
                  <ArrowRight size={18} />
                </Link>
                <div className="mt-6 flex flex-col gap-1">
                  <a href={`mailto:${site.email}`} className="text-meta text-mist hover:text-reef">
                    {site.email}
                  </a>
                  <a href={site.phoneHref} className="text-meta text-mist hover:text-reef">
                    {site.phone}
                  </a>
                </div>
              </motion.div>
            </div>
          </motion.div>
        ) : null}
      </AnimatePresence>
    </>
  );
}
