import type { ReactNode } from "react";
import { cn } from "@/lib/cn";

/** Vertical rhythm wrapper. `tone` alternates the section background. */
export function Section({
  children,
  className,
  tone = "base",
  id,
  size = "md",
  as: Tag = "section",
}: {
  children: ReactNode;
  className?: string;
  tone?: "base" | "raised" | "none";
  id?: string;
  size?: "sm" | "md" | "lg";
  as?: "section" | "div";
}) {
  const pad = {
    sm: "py-16 md:py-20",
    md: "py-20 md:py-28",
    lg: "py-24 md:py-36",
  }[size];

  return (
    <Tag
      id={id}
      className={cn(
        "overflow-x-clip",
        tone === "raised" && "border-y border-line bg-ink-2",
        tone === "base" && "bg-ink",
        pad,
        className,
      )}
    >
      <div className="shell">{children}</div>
    </Tag>
  );
}
