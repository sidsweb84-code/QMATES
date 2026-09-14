"use client";

/* ============================================================================
 * FORM FIELDS
 * Shared, accessible inputs used by both the quote and contact forms.
 * Every field has: a visible <label>, a programmatic error association via
 * aria-describedby, aria-invalid on failure, and a 48px minimum height.
 * Errors are announced with role="alert".
 * ========================================================================== */

import type { ReactNode } from "react";
import { cn } from "@/lib/cn";
import { Alert, Check, ChevronDown } from "./Icon";

const control =
  "w-full min-h-12 rounded-[var(--radius-md)] border bg-surface-2 px-4 py-3 text-[0.9375rem] " +
  "text-bone placeholder:text-dim/70 transition-[border-color,background-color,box-shadow] " +
  "duration-[var(--duration-base)] hover:border-line-strong " +
  "focus:border-reef focus:bg-surface-3 focus:outline-none " +
  "focus-visible:ring-2 focus-visible:ring-reef/35";

function Shell({
  id,
  label,
  hint,
  error,
  required,
  children,
  className,
}: {
  id: string;
  label: string;
  hint?: string;
  error?: string;
  required?: boolean;
  children: ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("flex flex-col gap-2", className)}>
      <label htmlFor={id} className="flex items-baseline gap-1.5 text-[0.875rem] font-medium text-bone">
        {label}
        {required ? (
          <span className="text-reef" aria-hidden="true">
            *
          </span>
        ) : (
          <span className="text-[0.75rem] font-normal text-dim">(optional)</span>
        )}
      </label>
      {hint ? (
        <p id={`${id}-hint`} className="text-[0.75rem] text-dim">
          {hint}
        </p>
      ) : null}
      {children}
      {error ? (
        <p
          id={`${id}-error`}
          role="alert"
          className="flex items-start gap-1.5 text-[0.8125rem] text-negative"
        >
          <Alert size={15} className="mt-px shrink-0" />
          {error}
        </p>
      ) : null}
    </div>
  );
}

function describedBy(id: string, hint?: string, error?: string) {
  return [hint ? `${id}-hint` : null, error ? `${id}-error` : null].filter(Boolean).join(" ") || undefined;
}

type Base = {
  id: string;
  label: string;
  hint?: string;
  error?: string;
  required?: boolean;
  className?: string;
};

export function TextField({
  id,
  label,
  hint,
  error,
  required,
  className,
  type = "text",
  ...rest
}: Base & React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <Shell id={id} label={label} hint={hint} error={error} required={required} className={className}>
      <input
        id={id}
        name={id}
        type={type}
        required={required}
        aria-invalid={error ? true : undefined}
        aria-describedby={describedBy(id, hint, error)}
        className={cn(control, error ? "border-negative bg-negative-soft/40" : "border-line")}
        {...rest}
      />
    </Shell>
  );
}

export function TextArea({
  id,
  label,
  hint,
  error,
  required,
  className,
  rows = 5,
  ...rest
}: Base & React.TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return (
    <Shell id={id} label={label} hint={hint} error={error} required={required} className={className}>
      <textarea
        id={id}
        name={id}
        rows={rows}
        required={required}
        aria-invalid={error ? true : undefined}
        aria-describedby={describedBy(id, hint, error)}
        className={cn(control, "resize-y", error ? "border-negative bg-negative-soft/40" : "border-line")}
        {...rest}
      />
    </Shell>
  );
}

export function SelectField({
  id,
  label,
  hint,
  error,
  required,
  className,
  options,
  ...rest
}: Base & React.SelectHTMLAttributes<HTMLSelectElement> & { options: string[] }) {
  return (
    <Shell id={id} label={label} hint={hint} error={error} required={required} className={className}>
      <div className="relative">
        <select
          id={id}
          name={id}
          required={required}
          aria-invalid={error ? true : undefined}
          aria-describedby={describedBy(id, hint, error)}
          className={cn(
            control,
            "cursor-pointer appearance-none pr-11",
            error ? "border-negative bg-negative-soft/40" : "border-line",
          )}
          {...rest}
        >
          <option value="">Select an option</option>
          {options.map((o) => (
            <option key={o} value={o}>
              {o}
            </option>
          ))}
        </select>
        <ChevronDown
          size={17}
          className="pointer-events-none absolute top-1/2 right-4 -translate-y-1/2 text-dim"
        />
      </div>
    </Shell>
  );
}

/** Card-style radio group — larger targets and a clearer selected state. */
export function RadioCards({
  name,
  legend,
  options,
  value,
  onChange,
  error,
  required,
  columns = 2,
}: {
  name: string;
  legend: string;
  options: { value: string; label: string; note?: string }[];
  value: string;
  onChange: (v: string) => void;
  error?: string;
  required?: boolean;
  columns?: 2 | 3;
}) {
  return (
    <fieldset
      aria-invalid={error ? true : undefined}
      aria-describedby={error ? `${name}-error` : undefined}
    >
      <legend className="flex items-baseline gap-1.5 text-[0.875rem] font-medium text-bone">
        {legend}
        {required ? (
          <span className="text-reef" aria-hidden="true">
            *
          </span>
        ) : null}
      </legend>
      <div
        className={cn(
          "mt-3 grid gap-3",
          columns === 3 ? "sm:grid-cols-3" : "sm:grid-cols-2",
        )}
      >
        {options.map((o) => {
          const checked = value === o.value;
          return (
            <label
              key={o.value}
              className={cn(
                "group/rc relative flex cursor-pointer flex-col gap-1 rounded-[var(--radius-md)] border p-4",
                "transition-[border-color,background-color] duration-[var(--duration-base)]",
                checked
                  ? "border-reef bg-reef/8"
                  : "border-line bg-surface-2 hover:border-line-strong",
                error && !checked ? "border-negative/60" : "",
              )}
            >
              <input
                type="radio"
                name={name}
                value={o.value}
                checked={checked}
                onChange={() => onChange(o.value)}
                className="sr-only"
              />
              <span className="flex items-center justify-between gap-3">
                <span className="text-[0.9375rem] font-medium text-bone">{o.label}</span>
                <span
                  aria-hidden="true"
                  className={cn(
                    "flex size-5 shrink-0 items-center justify-center rounded-full border transition-colors",
                    "duration-[var(--duration-base)]",
                    checked ? "border-reef bg-reef text-reef-ink" : "border-line-strong",
                  )}
                >
                  {checked ? <Check size={12} /> : null}
                </span>
              </span>
              {o.note ? <span className="text-[0.75rem] text-dim">{o.note}</span> : null}
            </label>
          );
        })}
      </div>
      {error ? (
        <p
          id={`${name}-error`}
          role="alert"
          className="mt-3 flex items-start gap-1.5 text-[0.8125rem] text-negative"
        >
          <Alert size={15} className="mt-px shrink-0" />
          {error}
        </p>
      ) : null}
    </fieldset>
  );
}

/** Multi-select checkbox chips. */
export function CheckGroup({
  name,
  legend,
  hint,
  options,
  values,
  onToggle,
}: {
  name: string;
  legend: string;
  hint?: string;
  options: string[];
  values: string[];
  onToggle: (v: string) => void;
}) {
  return (
    <fieldset>
      <legend className="text-[0.875rem] font-medium text-bone">
        {legend} <span className="text-[0.75rem] font-normal text-dim">(optional)</span>
      </legend>
      {hint ? <p className="mt-1.5 text-[0.75rem] text-dim">{hint}</p> : null}
      <div className="mt-3 flex flex-wrap gap-2.5">
        {options.map((o) => {
          const checked = values.includes(o);
          return (
            <label
              key={o}
              className={cn(
                "inline-flex min-h-11 cursor-pointer items-center gap-2 rounded-[var(--radius-md)]",
                "border px-3.5 text-[0.875rem] transition-colors duration-[var(--duration-base)]",
                checked
                  ? "border-reef bg-reef/10 text-bone"
                  : "border-line bg-surface-2 text-mist hover:border-line-strong hover:text-bone",
              )}
            >
              <input
                type="checkbox"
                name={name}
                value={o}
                checked={checked}
                onChange={() => onToggle(o)}
                className="sr-only"
              />
              <span
                aria-hidden="true"
                className={cn(
                  "flex size-4 shrink-0 items-center justify-center rounded-[3px] border transition-colors",
                  "duration-[var(--duration-base)]",
                  checked ? "border-reef bg-reef text-reef-ink" : "border-line-strong",
                )}
              >
                {checked ? <Check size={11} /> : null}
              </span>
              {o}
            </label>
          );
        })}
      </div>
    </fieldset>
  );
}
