/* ============================================================================
 * BUTTON SYSTEM
 * ----------------------------------------------------------------------------
 * Deliberately not one shape repeated everywhere. Five variants, each with a
 * different hover mechanic:
 *   solid    — label lifts and is replaced by a duplicate rising from below
 *   sand     — same mechanic, secondary accent, used sparingly
 *   outline  — reef fill wipes up from the bottom edge
 *   ghost    — a rule under the label draws in from the left
 *   quiet    — subtle surface lift, used inside dense UI
 * All variants share: arrow rotation to up-right, press state, focus ring.
 * ========================================================================== */

import Link from "next/link";
import type { ComponentPropsWithoutRef, ReactNode } from "react";
import { cn } from "@/lib/cn";
import { ArrowRight, Spinner } from "./Icon";

type Variant = "solid" | "sand" | "outline" | "ghost" | "quiet";
type Size = "sm" | "md" | "lg";

const base =
  "group/btn relative inline-flex items-center justify-center gap-2.5 font-medium " +
  "cursor-pointer select-none whitespace-nowrap " +
  "transition-[transform,background-color,border-color,color,box-shadow] duration-[var(--duration-base)] ease-[var(--ease-out-expo)] " +
  "active:translate-y-px disabled:pointer-events-none disabled:opacity-45";

const sizes: Record<Size, string> = {
  sm: "min-h-11 px-4 text-[0.8125rem] rounded-[var(--radius-sm)]",
  md: "min-h-12 px-5 text-[0.9375rem] rounded-[var(--radius-md)]",
  lg: "min-h-14 px-7 text-base rounded-[var(--radius-md)]",
};

const variants: Record<Variant, string> = {
  solid:
    "bg-reef text-reef-ink font-semibold shadow-[0_12px_32px_-16px_rgb(55_217_190/0.9)] " +
    "hover:bg-[#4ee7cd] hover:shadow-[0_18px_44px_-16px_rgb(55_217_190/0.75)]",
  sand:
    "bg-sand text-sand-ink font-semibold shadow-[0_12px_32px_-16px_rgb(233_201_155/0.8)] " +
    "hover:bg-[#f3d7ae]",
  outline:
    "border border-line-strong text-bone overflow-hidden isolate " +
    "hover:border-reef hover:text-reef-ink",
  ghost: "text-bone px-0 min-h-10 hover:text-reef",
  quiet:
    "bg-surface-2 text-bone border border-line hover:bg-surface-3 hover:border-line-strong",
};

type SharedProps = {
  children: ReactNode;
  variant?: Variant;
  size?: Size;
  /** Shows a right arrow that rotates to point up-right on hover. */
  withArrow?: boolean;
  loading?: boolean;
  className?: string;
};

/** The rising-duplicate label used by the two solid variants. */
function SwapLabel({ children }: { children: ReactNode }) {
  return (
    <span className="relative grid overflow-hidden">
      <span
        className={cn(
          "col-start-1 row-start-1 transition-transform duration-[var(--duration-base)]",
          "ease-[var(--ease-out-expo)] group-hover/btn:-translate-y-[130%]",
        )}
      >
        {children}
      </span>
      <span
        aria-hidden="true"
        className={cn(
          "col-start-1 row-start-1 translate-y-[130%] transition-transform",
          "duration-[var(--duration-base)] ease-[var(--ease-out-expo)] group-hover/btn:translate-y-0",
        )}
      >
        {children}
      </span>
    </span>
  );
}

function Inner({
  children,
  variant,
  withArrow,
  loading,
}: {
  children: ReactNode;
  variant: Variant;
  withArrow?: boolean;
  loading?: boolean;
}) {
  const swaps = variant === "solid" || variant === "sand";
  return (
    <>
      {/* outline: reef fill wipes up from the bottom edge on hover */}
      {variant === "outline" ? (
        <span
          aria-hidden="true"
          className={cn(
            "absolute inset-0 -z-10 origin-bottom scale-y-0 bg-reef",
            "transition-transform duration-[var(--duration-base)] ease-[var(--ease-out-expo)]",
            "group-hover/btn:scale-y-100",
          )}
        />
      ) : null}

      {loading ? <Spinner size={17} /> : null}

      {swaps ? <SwapLabel>{children}</SwapLabel> : <span>{children}</span>}

      {/* ghost: rule draws in from the left */}
      {variant === "ghost" ? (
        <span
          aria-hidden="true"
          className={cn(
            "absolute -bottom-0.5 left-0 h-px w-full origin-left scale-x-0 bg-reef",
            "transition-transform duration-[var(--duration-base)] ease-[var(--ease-out-expo)]",
            "group-hover/btn:scale-x-100",
          )}
        />
      ) : null}

      {withArrow && !loading ? (
        <ArrowRight
          size={17}
          className={cn(
            "shrink-0 transition-transform duration-[var(--duration-base)] ease-[var(--ease-out-expo)]",
            "group-hover/btn:-translate-y-px group-hover/btn:translate-x-0.5 group-hover/btn:-rotate-45",
          )}
        />
      ) : null}
    </>
  );
}

type LinkButtonProps = SharedProps &
  Omit<ComponentPropsWithoutRef<typeof Link>, "className" | "children"> & { href: string };

export function ButtonLink({
  children,
  href,
  variant = "solid",
  size = "md",
  withArrow,
  className,
  ...rest
}: LinkButtonProps) {
  return (
    <Link href={href} className={cn(base, sizes[size], variants[variant], className)} {...rest}>
      <Inner variant={variant} withArrow={withArrow}>
        {children}
      </Inner>
    </Link>
  );
}

type NativeButtonProps = SharedProps & ComponentPropsWithoutRef<"button">;

export function Button({
  children,
  variant = "solid",
  size = "md",
  withArrow,
  loading,
  className,
  type = "button",
  disabled,
  ...rest
}: NativeButtonProps) {
  return (
    <button
      type={type}
      disabled={disabled || loading}
      className={cn(base, sizes[size], variants[variant], className)}
      {...rest}
    >
      <Inner variant={variant} withArrow={withArrow} loading={loading}>
        {children}
      </Inner>
    </button>
  );
}

/** An external anchor styled as a button (used for mailto/tel links). */
export function ButtonAnchor({
  children,
  href,
  variant = "outline",
  size = "md",
  withArrow,
  className,
  ...rest
}: SharedProps & ComponentPropsWithoutRef<"a"> & { href: string }) {
  return (
    <a href={href} className={cn(base, sizes[size], variants[variant], className)} {...rest}>
      <Inner variant={variant} withArrow={withArrow}>
        {children}
      </Inner>
    </a>
  );
}
