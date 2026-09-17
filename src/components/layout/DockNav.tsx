"use client";

/* ============================================================================
 * DOCK NAV
 * ----------------------------------------------------------------------------
 * A floating navigation pill that rises once the visitor has scrolled past the
 * hero, so the primary routes and the quote CTA stay one tap away no matter
 * how far down the page they are.
 *
 * Five destinations, which is the documented ceiling for a bottom bar before
 * the targets get too tight to hit. Each carries an icon AND a label — an
 * icon-only bar is a guessing game.
 * ========================================================================== */

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { cn } from "@/lib/cn";
import { Briefcase, Grid, Home, Mail, Tag, User } from "@/components/ui/Icon";

const items = [
  { label: "Home", href: "/", Icon: Home },
  { label: "Work", href: "/portfolio", Icon: Briefcase },
  { label: "Gallery", href: "/gallery", Icon: Grid },
  { label: "Pricing", href: "/pricing", Icon: Tag },
  { label: "About", href: "/about", Icon: User },
] as const;

function isActive(pathname: string, href: string) {
  if (href === "/") return pathname === "/";
  return pathname === href || pathname.startsWith(`${href}/`);
}

export function DockNav() {
  const pathname = usePathname();
  const [shown, setShown] = useState(false);

  useEffect(() => {
    const onScroll = () => setShown(window.scrollY > 420);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <div
      className={cn(
        "pointer-events-none fixed inset-x-0 bottom-4 z-40 flex justify-center px-4",
        "transition-[opacity,transform] duration-[var(--duration-slow)] ease-[var(--ease-out-expo)]",
        shown ? "translate-y-0 opacity-100" : "pointer-events-none translate-y-6 opacity-0",
      )}
    >
      <nav
        aria-label="Quick navigation"
        aria-hidden={!shown}
        className={cn(
          "pointer-events-auto flex items-center gap-0.5 rounded-full border border-line-strong",
          "bg-surface/85 p-1.5 shadow-[var(--shadow-high)] backdrop-blur-xl sm:gap-1",
        )}
      >
        <ul className="flex items-center gap-0.5">
          {items.map(({ label, href, Icon }) => {
            const active = isActive(pathname, href);
            return (
              <li key={href}>
                <Link
                  href={href}
                  tabIndex={shown ? undefined : -1}
                  aria-current={active ? "page" : undefined}
                  className={cn(
                    "group/dock flex min-h-11 items-center gap-2 rounded-full px-3 sm:px-3.5",
                    "text-[0.8125rem] transition-colors duration-[var(--duration-base)]",
                    active
                      ? "bg-bone text-ink"
                      : "text-mist hover:bg-surface-3 hover:text-bone",
                  )}
                >
                  <Icon
                    size={17}
                    className="shrink-0 transition-transform duration-[var(--duration-base)] ease-[var(--ease-out-expo)] group-hover/dock:-translate-y-0.5"
                  />
                  {/* Labels collapse as the screen narrows so five targets keep
                      their full 44px height instead of being squeezed. Below
                      380px even the active label goes: the filled pill and
                      aria-current still say which page you are on. */}
                  <span className={cn(active ? "hidden min-[380px]:inline" : "hidden sm:inline")}>
                    {label}
                  </span>
                </Link>
              </li>
            );
          })}
        </ul>

        <Link
          href="/quote"
          tabIndex={shown ? undefined : -1}
          aria-label="Get a quote"
          className={cn(
            "group/cta ml-0.5 flex size-11 shrink-0 items-center justify-center rounded-full sm:ml-1",
            "bg-reef text-reef-ink transition-[background-color,transform]",
            "duration-[var(--duration-base)] ease-[var(--ease-out-expo)]",
            "hover:scale-105 hover:bg-[#4ee7cd]",
          )}
        >
          <Mail
            size={18}
            className="transition-transform duration-[var(--duration-base)] group-hover/cta:-translate-y-px"
          />
        </Link>
      </nav>
    </div>
  );
}
