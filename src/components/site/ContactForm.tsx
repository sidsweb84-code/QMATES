"use client";

/* ============================================================================
 * CONTACT FORM
 * Deliberately short and single-step — this page is for general questions,
 * not for scoping a project. Anyone ready to scope goes to /quote instead.
 *
 * DELIVERY: /api/contact validates and acknowledges but does not send email.
 * The success state says so and offers a pre-filled mailto fallback.
 * ========================================================================== */

import { useRef, useState } from "react";
import { cn } from "@/lib/cn";
import { site } from "@/data/site";
import { sendToWeb3Forms, validateContact, type ContactPayload } from "@/lib/enquiry";
import { Button } from "@/components/ui/Button";
import { SelectField, TextArea, TextField } from "@/components/ui/Field";
import { Alert, Check, Mail } from "@/components/ui/Icon";

const SUBJECTS = [
  "General question",
  "About an existing site",
  "Maintenance or updates",
  "Something else",
];

const EMPTY: ContactPayload = { name: "", email: "", subject: "", message: "" };

export function ContactForm() {
  const [values, setValues] = useState<ContactPayload>(EMPTY);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [touched, setTouched] = useState<Record<string, boolean>>({});
  const [status, setStatus] = useState<"idle" | "sending" | "sent" | "failed">("idle");
  const [botcheck, setBotcheck] = useState(false);
  const [failMessage, setFailMessage] = useState("");
  const alertRef = useRef<HTMLDivElement>(null);
  const doneRef = useRef<HTMLDivElement>(null);

  const set = <K extends keyof ContactPayload>(k: K, v: ContactPayload[K]) => {
    setValues((s) => ({ ...s, [k]: v }));
    if (errors[k]) setErrors((e) => ({ ...e, [k]: "" }));
  };

  const blur = (k: keyof ContactPayload) => {
    setTouched((t) => ({ ...t, [k]: true }));
    const next = validateContact(values);
    setErrors((e) => ({ ...e, [k]: next[k] ?? "" }));
  };

  const errorFor = (k: keyof ContactPayload) =>
    touched[k] || status === "failed" ? errors[k] || undefined : undefined;

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    const found = validateContact(values);

    if (Object.keys(found).length > 0) {
      setErrors(found);
      setTouched(Object.fromEntries(Object.keys(found).map((k) => [k, true])));
      setStatus("failed");
      setFailMessage("");
      window.requestAnimationFrame(() => alertRef.current?.focus());
      return;
    }

    setStatus("sending");

    const sent = await sendToWeb3Forms({
      accessKey: site.web3formsKey,
      subject: values.subject
        ? `Website enquiry — ${values.subject}`
        : "Website enquiry",
      replyTo: values.email,
      botcheck,
      fields: {
        Name: values.name,
        Email: values.email,
        Subject: values.subject,
        Message: values.message,
      },
    });

    if (!sent.ok) {
      setStatus("failed");
      setFailMessage(sent.message);
      window.requestAnimationFrame(() => alertRef.current?.focus());
      return;
    }

    setStatus("sent");
    window.requestAnimationFrame(() => doneRef.current?.focus());
  }

  if (status === "sent") {
    return (
      <div
        ref={doneRef}
        tabIndex={-1}
        className="rounded-[var(--radius-lg)] border border-reef/35 bg-surface p-7 outline-none md:p-8"
      >
        <span className="flex size-11 items-center justify-center rounded-full bg-reef text-reef-ink">
          <Check size={22} />
        </span>
        <h2 className="mt-5 text-h3 text-bone">Message sent</h2>
        <p className="mt-3 text-meta text-mist">
          It is on its way to {site.email}. You will normally get a reply within
          two business days.
        </p>
        <div className="mt-6">
          <Button
            variant="outline"
            onClick={() => {
              setStatus("idle");
              setValues(EMPTY);
              setErrors({});
              setTouched({});
            }}
          >
            Write another
          </Button>
        </div>
      </div>
    );
  }

  const listed = Object.entries(errors).filter(([, v]) => v);

  return (
    <form onSubmit={submit} noValidate className="flex flex-col gap-6">
      {/* Honeypot — hidden from people, filled in by bots. */}
      <label className="sr-only" aria-hidden="true">
        Leave this field empty
        <input
          type="checkbox"
          name="botcheck"
          tabIndex={-1}
          autoComplete="off"
          checked={botcheck}
          onChange={(e) => setBotcheck(e.target.checked)}
        />
      </label>
      {status === "failed" && (listed.length > 0 || failMessage) ? (
        <div
          ref={alertRef}
          tabIndex={-1}
          role="alert"
          className="rounded-[var(--radius-md)] border border-negative/50 bg-negative-soft p-4 outline-none"
        >
          <p className="flex items-center gap-2 text-[0.875rem] font-medium text-negative">
            <Alert size={16} />
            {failMessage || "Check the highlighted fields below."}
          </p>
          <ul className="mt-2.5 flex flex-col gap-1.5">
            {listed.map(([k, m]) => (
              <li key={k}>
                <a
                  href={`#${k}`}
                  onClick={(e) => {
                    e.preventDefault();
                    document.getElementById(k)?.focus();
                  }}
                  className={cn(
                    "inline-flex min-h-6 items-center py-0.5 text-[0.8125rem]",
                    "text-negative underline underline-offset-4 hover:text-bone",
                  )}
                >
                  {m}
                </a>
              </li>
            ))}
          </ul>
        </div>
      ) : null}

      <div className="grid gap-6 sm:grid-cols-2">
        <TextField
          id="name"
          label="Your name"
          required
          autoComplete="name"
          value={values.name}
          onChange={(e) => set("name", e.target.value)}
          onBlur={() => blur("name")}
          error={errorFor("name")}
        />
        <TextField
          id="email"
          label="Email"
          type="email"
          inputMode="email"
          required
          autoComplete="email"
          value={values.email}
          onChange={(e) => set("email", e.target.value)}
          onBlur={() => blur("email")}
          error={errorFor("email")}
        />
      </div>

      <SelectField
        id="subject"
        label="What is it about?"
        options={SUBJECTS}
        value={values.subject}
        onChange={(e) => set("subject", e.target.value)}
      />

      <TextArea
        id="message"
        label="Message"
        required
        rows={6}
        placeholder="Ask anything — no detail required."
        value={values.message}
        onChange={(e) => set("message", e.target.value)}
        onBlur={() => blur("message")}
        error={errorFor("message")}
      />

      <div className="flex flex-col-reverse items-start gap-4 sm:flex-row sm:items-center sm:justify-between">
        <p className="text-[0.75rem] text-dim">
          <span className="text-reef">*</span> Required. Replies usually within two
          business days.
        </p>
        <Button type="submit" size="lg" withArrow loading={status === "sending"}>
          {status === "sending" ? "Sending…" : "Send message"}
        </Button>
      </div>
    </form>
  );
}
