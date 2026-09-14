"use client";

/* ============================================================================
 * QUOTE FORM
 * Three steps with per-step validation, an error summary that takes focus on
 * a failed submit, a loading state, and an honest success state.
 *
 * DELIVERY: /api/quote validates and acknowledges but does not send email —
 * no provider is configured. The success state says so plainly and gives the
 * visitor a mailto carrying their full submission so the enquiry still
 * actually reaches a person today.
 * ========================================================================== */

import { AnimatePresence,  motion } from "motion/react";
import { useRef, useState } from "react";
import { cn } from "@/lib/cn";
import { site } from "@/data/site";
import {
  formatQuote,
  quoteSteps,
  validateQuote,
  type QuotePayload,
} from "@/lib/enquiry";
import { Button } from "@/components/ui/Button";
import {
  CheckGroup,
  RadioCards,
  SelectField,
  TextArea,
  TextField,
} from "@/components/ui/Field";
import { Alert, ArrowLeft, ArrowRight, Check, Mail } from "@/components/ui/Icon";

const BUSINESS_TYPES = [
  "Trades & construction",
  "Hospitality",
  "Health & wellbeing",
  "Professional services",
  "Retail & e-commerce",
  "Property & real estate",
  "Creative & events",
  "Other",
];

const PROJECT_TYPES = [
  { value: "New website", label: "A new website", note: "Starting from nothing" },
  { value: "Redesign", label: "A redesign", note: "I have a site, it needs replacing" },
  { value: "Improvements", label: "Improvements", note: "Fix or extend what exists" },
  { value: "Not sure yet", label: "Not sure yet", note: "Help me work it out" },
];

const PAGE_COUNTS = ["1–3 pages", "4–6 pages", "7–12 pages", "12+ pages", "Not sure yet"];

const FEATURES = [
  "Contact form",
  "Quote or booking flow",
  "Online payments",
  "Photo gallery",
  "Blog or news",
  "Menu or price list",
  "Customer reviews",
  "Maps & directions",
  "Multi-location",
  "Copywriting help",
];

const BUDGETS = [
  "Under $1,500",
  "$1,500 – $3,000",
  "$3,000 – $6,000",
  "$6,000 +",
  "Not sure — advise me",
];

const TIMEFRAMES = ["As soon as possible", "Within 1 month", "1–3 months", "3+ months", "Just exploring"];

const EMPTY: QuotePayload = {
  name: "",
  business: "",
  email: "",
  phone: "",
  businessType: "",
  existingSite: "",
  projectType: "",
  pages: "",
  features: [],
  budget: "",
  timeframe: "",
  notes: "",
};

type Status = "idle" | "sending" | "sent" | "failed";

export function QuoteForm() {
  const [step, setStep] = useState(0);
  const [values, setValues] = useState<QuotePayload>(EMPTY);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [touched, setTouched] = useState<Record<string, boolean>>({});
  const [status, setStatus] = useState<Status>("idle");
  const [result, setResult] = useState<{ reference: string; delivered: boolean } | null>(null);
  const [failMessage, setFailMessage] = useState("");
  /* True once any validation attempt has blocked, so the summary renders for
     a blocked step advance as well as a blocked submit. */
  const [blocked, setBlocked] = useState(false);

  const summaryRef = useRef<HTMLDivElement>(null);
  const headingRef = useRef<HTMLParagraphElement>(null);
  const successRef = useRef<HTMLDivElement>(null);

  const set = <K extends keyof QuotePayload>(key: K, value: QuotePayload[K]) => {
    setValues((v) => ({ ...v, [key]: value }));
    // Clear an error as soon as the visitor starts correcting it.
    if (errors[key]) setErrors((e) => ({ ...e, [key]: "" }));
    if (status === "failed") setStatus("idle");
  };

  /** Validate only on blur, and only the fields the visitor has left. */
  const blur = (key: keyof QuotePayload) => {
    setTouched((t) => ({ ...t, [key]: true }));
    const next = validateQuote(values);
    setErrors((e) => ({ ...e, [key]: next[key] ?? "" }));
  };

  const errorFor = (key: keyof QuotePayload) =>
    touched[key] || status === "failed" ? errors[key] || undefined : undefined;

  const stepErrors = (index: number) => {
    const all = validateQuote(values);
    const fields = quoteSteps[index].fields as readonly string[];
    return Object.fromEntries(
      Object.entries(all).filter(([k]) => fields.includes(k)),
    );
  };

  const next = (e?: React.MouseEvent) => {
    e?.preventDefault();
    const found = stepErrors(step);
    if (Object.keys(found).length > 0) {
      setErrors((e) => ({ ...e, ...found }));
      setTouched((t) => ({
        ...t,
        ...Object.fromEntries(Object.keys(found).map((k) => [k, true])),
      }));
      setBlocked(true);
      setFailMessage("");
      window.requestAnimationFrame(() => summaryRef.current?.focus());
      return;
    }
    setStep((s) => Math.min(s + 1, quoteSteps.length - 1));
    window.requestAnimationFrame(() => headingRef.current?.focus());
  };

  const back = (e?: React.MouseEvent) => {
    e?.preventDefault();
    setStep((s) => Math.max(s - 1, 0));
    window.requestAnimationFrame(() => headingRef.current?.focus());
  };

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    const found = validateQuote(values);

    if (Object.keys(found).length > 0) {
      setErrors(found);
      setTouched(Object.fromEntries(Object.keys(found).map((k) => [k, true])));
      setStatus("failed");
      setBlocked(true);
      setFailMessage("");
      // Jump to the earliest step still carrying an error.
      const firstBad = quoteSteps.findIndex((s) =>
        (s.fields as readonly string[]).some((f) => f in found),
      );
      if (firstBad !== -1) setStep(firstBad);
      window.requestAnimationFrame(() => summaryRef.current?.focus());
      return;
    }

    setStatus("sending");
    try {
      const res = await fetch("/api/quote", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(values),
      });
      const data = await res.json();

      if (!res.ok || !data.ok) {
        setErrors(data.errors ?? {});
        setStatus("failed");
        setFailMessage(
          data.message ?? "Something went wrong submitting the form. Please try again.",
        );
        window.requestAnimationFrame(() => summaryRef.current?.focus());
        return;
      }

      setResult({ reference: data.reference, delivered: Boolean(data.delivered) });
      setStatus("sent");
      window.requestAnimationFrame(() => successRef.current?.focus());
    } catch {
      setStatus("failed");
      setFailMessage(
        "The request could not be sent — you may be offline. Try again, or email the details directly.",
      );
      window.requestAnimationFrame(() => summaryRef.current?.focus());
    }
  }

  /* ---------------------------- success state ---------------------------- */
  if (status === "sent" && result) {
    const mailto = `mailto:${site.email}?subject=${encodeURIComponent(
      `Website quote request — ${values.business || values.name}`,
    )}&body=${encodeURIComponent(formatQuote(values))}`;

    return (
      <div
        ref={successRef}
        tabIndex={-1}
        className="rounded-[var(--radius-lg)] border border-reef/35 bg-surface p-7 outline-none md:p-10"
      >
        <span className="flex size-12 items-center justify-center rounded-full bg-reef text-reef-ink">
          <Check size={24} />
        </span>
        <h2 className="mt-6 text-h2 text-bone">Your request has been captured.</h2>
        <p className="mt-4 max-w-xl text-lead text-mist">
          Reference <span className="nums font-semibold text-bone">{result.reference}</span>.
          Everything you entered passed validation and was recorded by the site.
        </p>

        {!result.delivered ? (
          <div className="mt-8 rounded-[var(--radius-md)] border border-sand/30 bg-sand/[0.07] p-5">
            <p className="eyebrow mb-2.5 flex items-center gap-2 text-sand">
              <Alert size={15} />
              One honest caveat
            </p>
            <p className="text-meta text-mist">
              This site has no email provider connected yet, so{" "}
              <strong className="font-semibold text-bone">
                your request has not been emailed to anyone
              </strong>
              . Use the button below to send the exact same details straight to{" "}
              {site.email} from your own mail app — it is pre-filled with
              everything you just entered.
            </p>
          </div>
        ) : null}

        <div className="mt-8 flex flex-col gap-3 sm:flex-row">
          <a
            href={mailto}
            className={cn(
              "group/m inline-flex min-h-14 cursor-pointer items-center justify-center gap-2.5",
              "rounded-[var(--radius-md)] bg-reef px-7 font-semibold text-reef-ink",
              "transition-colors duration-[var(--duration-base)] hover:bg-[#4ee7cd]",
            )}
          >
            <Mail size={18} />
            Send it by email now
          </a>
          <Button
            variant="outline"
            size="lg"
            onClick={() => {
              setStatus("idle");
              setStep(0);
              setValues(EMPTY);
              setErrors({});
              setTouched({});
              setBlocked(false);
              setResult(null);
            }}
          >
            Submit another request
          </Button>
        </div>

        <details className="mt-8">
          <summary className="inline-flex min-h-10 cursor-pointer items-center text-meta text-mist transition-colors duration-[var(--duration-base)] hover:text-reef">
            Review what you submitted
          </summary>
          <pre className="mt-4 overflow-x-auto rounded-[var(--radius-md)] border border-line bg-ink-2 p-4 text-[0.8125rem] whitespace-pre-wrap text-mist">
            {formatQuote(values)}
          </pre>
        </details>
      </div>
    );
  }

  /* ------------------------------- the form ------------------------------ */
  const visibleErrors = Object.entries(errors).filter(([, v]) => v);
  const showSummary = blocked && visibleErrors.length > 0;

  return (
    <form onSubmit={submit} noValidate className="flex flex-col gap-8">
      {/* --- progress --- */}
      <ol className="flex flex-col gap-3 sm:flex-row sm:items-center sm:gap-2">
        {quoteSteps.map((s, i) => {
          const done = i < step;
          const current = i === step;
          return (
            <li key={s.id} className="flex flex-1 items-center gap-3">
              <span
                className={cn(
                  "flex size-8 shrink-0 items-center justify-center rounded-full border text-[0.75rem]",
                  "transition-colors duration-[var(--duration-base)]",
                  current
                    ? "border-reef bg-reef text-reef-ink"
                    : done
                      ? "border-reef/50 text-reef"
                      : "border-line text-dim",
                )}
              >
                {done ? <Check size={14} /> : <span className="nums">{i + 1}</span>}
              </span>
              <span
                className={cn(
                  "text-[0.8125rem] transition-colors duration-[var(--duration-base)]",
                  current ? "font-medium text-bone" : "text-dim",
                )}
              >
                {s.title}
              </span>
              {i < quoteSteps.length - 1 ? (
                <span
                  aria-hidden="true"
                  className={cn(
                    "hidden h-px flex-1 transition-colors duration-[var(--duration-slow)] sm:block",
                    done ? "bg-reef/50" : "bg-line",
                  )}
                />
              ) : null}
            </li>
          );
        })}
      </ol>

      <p ref={headingRef} tabIndex={-1} className="sr-only" aria-live="polite">
        Step {step + 1} of {quoteSteps.length}: {quoteSteps[step].title}
      </p>

      {/* --- error summary --- */}
      {showSummary ? (
        <div
          ref={summaryRef}
          tabIndex={-1}
          role="alert"
          className="rounded-[var(--radius-md)] border border-negative/50 bg-negative-soft p-5 outline-none"
        >
          <p className="flex items-center gap-2 font-medium text-negative">
            <Alert size={17} />
            {failMessage ||
              `There ${visibleErrors.length === 1 ? "is 1 answer" : `are ${visibleErrors.length} answers`} that need attention.`}
          </p>
          {visibleErrors.length ? (
            <ul className="mt-3 flex flex-col gap-1.5">
              {visibleErrors.map(([key, message]) => (
                <li key={key}>
                  <a
                    href={`#${key}`}
                    onClick={(e) => {
                      e.preventDefault();
                      const bad = quoteSteps.findIndex((s) =>
                        (s.fields as readonly string[]).includes(key),
                      );
                      if (bad !== -1) setStep(bad);
                      window.requestAnimationFrame(() =>
                        document.getElementById(key)?.focus(),
                      );
                    }}
                    className="inline-flex min-h-6 items-center py-0.5 text-[0.8125rem] text-negative underline underline-offset-4 hover:text-bone"
                  >
                    {message}
                  </a>
                </li>
              ))}
            </ul>
          ) : null}
        </div>
      ) : null}

      {/* --- steps --- */}
      <AnimatePresence mode="wait" initial={false}>
        <motion.fieldset
          key={quoteSteps[step].id}
          initial={{ opacity: 0, x: 16 }}
          animate={{ opacity: 1, x: 0 }}
          exit={{ opacity: 0, x: -16 }}
          transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
          className="flex flex-col gap-6"
        >
          <legend className="sr-only">{quoteSteps[step].title}</legend>

          {step === 0 ? (
            <>
              <div className="grid gap-6 sm:grid-cols-2">
                <TextField
                  id="name"
                  label="Your name"
                  required
                  autoComplete="name"
                  placeholder="Jordan Smith"
                  value={values.name}
                  onChange={(e) => set("name", e.target.value)}
                  onBlur={() => blur("name")}
                  error={errorFor("name")}
                />
                <TextField
                  id="business"
                  label="Business name"
                  autoComplete="organization"
                  placeholder="Smith & Co"
                  value={values.business}
                  onChange={(e) => set("business", e.target.value)}
                />
              </div>
              <div className="grid gap-6 sm:grid-cols-2">
                <TextField
                  id="email"
                  label="Email"
                  type="email"
                  inputMode="email"
                  required
                  autoComplete="email"
                  placeholder="you@business.com.au"
                  hint="The written quote comes back to this address."
                  value={values.email}
                  onChange={(e) => set("email", e.target.value)}
                  onBlur={() => blur("email")}
                  error={errorFor("email")}
                />
                <TextField
                  id="phone"
                  label="Phone"
                  type="tel"
                  inputMode="tel"
                  autoComplete="tel"
                  placeholder="0400 000 000"
                  hint="Only used if a quick call would be faster than email."
                  value={values.phone}
                  onChange={(e) => set("phone", e.target.value)}
                  onBlur={() => blur("phone")}
                  error={errorFor("phone")}
                />
              </div>
              <SelectField
                id="businessType"
                label="What kind of business is it?"
                options={BUSINESS_TYPES}
                value={values.businessType}
                onChange={(e) => set("businessType", e.target.value)}
              />
            </>
          ) : null}

          {step === 1 ? (
            <>
              <TextField
                id="existingSite"
                label="Existing website"
                type="url"
                inputMode="url"
                placeholder="https://yourbusiness.com.au"
                hint="Leave blank if you do not have one yet."
                value={values.existingSite}
                onChange={(e) => set("existingSite", e.target.value)}
              />
              <RadioCards
                name="projectType"
                legend="What do you need?"
                required
                options={PROJECT_TYPES}
                value={values.projectType}
                onChange={(v) => {
                  set("projectType", v);
                  setTouched((t) => ({ ...t, projectType: true }));
                }}
                error={errorFor("projectType")}
              />
              <SelectField
                id="pages"
                label="Roughly how many pages?"
                hint="A best guess is fine — this gets refined in the quote."
                options={PAGE_COUNTS}
                value={values.pages}
                onChange={(e) => set("pages", e.target.value)}
              />
              <CheckGroup
                name="features"
                legend="Anything specific you need?"
                hint="Select everything that applies."
                options={FEATURES}
                values={values.features}
                onToggle={(v) =>
                  set(
                    "features",
                    values.features.includes(v)
                      ? values.features.filter((f) => f !== v)
                      : [...values.features, v],
                  )
                }
              />
            </>
          ) : null}

          {step === 2 ? (
            <>
              <div className="grid gap-6 sm:grid-cols-2">
                <SelectField
                  id="budget"
                  label="Approximate budget"
                  hint="Used to scope the right package. Nothing is locked in."
                  options={BUDGETS}
                  value={values.budget}
                  onChange={(e) => set("budget", e.target.value)}
                />
                <SelectField
                  id="timeframe"
                  label="When do you need it live?"
                  options={TIMEFRAMES}
                  value={values.timeframe}
                  onChange={(e) => set("timeframe", e.target.value)}
                />
              </div>
              <TextArea
                id="notes"
                label="Anything else worth knowing?"
                rows={6}
                placeholder="What your customers usually ask before they buy, sites you like, anything that has to be on there…"
                value={values.notes}
                onChange={(e) => set("notes", e.target.value)}
              />
            </>
          ) : null}
        </motion.fieldset>
      </AnimatePresence>

      {/* --- controls --- */}
      <div className="rule-t flex flex-col-reverse gap-3 pt-6 sm:flex-row sm:items-center sm:justify-between">
        {step > 0 ? (
          <Button key="back" variant="ghost" onClick={back} className="sm:px-0">
            <span className="inline-flex items-center gap-2">
              <ArrowLeft size={16} />
              {quoteSteps[step - 1].title}
            </span>
          </Button>
        ) : (
          <p className="text-[0.75rem] text-dim">
            <span className="text-reef">*</span> Required. Takes about two minutes.
          </p>
        )}

        {step < quoteSteps.length - 1 ? (
          <Button key="continue" onClick={next} size="lg">
            <span className="inline-flex items-center gap-2">
              Continue
              <ArrowRight size={17} />
            </span>
          </Button>
        ) : (
          <Button key="submit" type="submit" size="lg" withArrow loading={status === "sending"}>
            {status === "sending" ? "Sending…" : "Send my request"}
          </Button>
        )}
      </div>
    </form>
  );
}
