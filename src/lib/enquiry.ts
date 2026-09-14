/* ============================================================================
 * ENQUIRY TYPES + SHARED VALIDATION
 * Used by the client forms and by the API routes, so a payload is validated
 * on both sides against exactly the same rules.
 * ========================================================================== */

export type QuotePayload = {
  name: string;
  business: string;
  email: string;
  phone: string;
  businessType: string;
  existingSite: string;
  projectType: string;
  pages: string;
  features: string[];
  budget: string;
  timeframe: string;
  notes: string;
};

export type ContactPayload = {
  name: string;
  email: string;
  subject: string;
  message: string;
};

export const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

export function validateQuote(v: Partial<QuotePayload>): Record<string, string> {
  const errors: Record<string, string> = {};
  if (!v.name?.trim()) errors.name = "Enter your name so I know who I am replying to.";
  if (!v.email?.trim()) errors.email = "Enter an email address so I can send the quote back.";
  else if (!EMAIL_RE.test(v.email.trim()))
    errors.email = "That does not look like a valid email address — check for a typo.";
  if (v.phone?.trim() && v.phone.replace(/\D/g, "").length < 8)
    errors.phone = "That phone number looks too short. Include the area or mobile prefix.";
  if (!v.projectType) errors.projectType = "Choose what you need so the quote can be scoped.";
  return errors;
}

export function validateContact(v: Partial<ContactPayload>): Record<string, string> {
  const errors: Record<string, string> = {};
  if (!v.name?.trim()) errors.name = "Enter your name.";
  if (!v.email?.trim()) errors.email = "Enter an email address so I can reply.";
  else if (!EMAIL_RE.test(v.email.trim())) errors.email = "That does not look like a valid email address.";
  if (!v.message?.trim()) errors.message = "Add a message — even a sentence is enough.";
  else if (v.message.trim().length < 10) errors.message = "Add a little more detail (at least 10 characters).";
  return errors;
}

/** Which fields belong to which step of the quote form. */
export const quoteSteps = [
  { id: "you", title: "About you", fields: ["name", "business", "email", "phone", "businessType"] },
  { id: "project", title: "The project", fields: ["existingSite", "projectType", "pages", "features"] },
  { id: "scope", title: "Budget & timing", fields: ["budget", "timeframe", "notes"] },
] as const;

/** Human-readable summary used for the mailto fallback and the API log. */
export function formatQuote(v: QuotePayload): string {
  const rows: [string, string][] = [
    ["Name", v.name],
    ["Business", v.business],
    ["Email", v.email],
    ["Phone", v.phone],
    ["Business type", v.businessType],
    ["Existing website", v.existingSite],
    ["What they need", v.projectType],
    ["Approx pages", v.pages],
    ["Features", v.features.join(", ")],
    ["Budget", v.budget],
    ["Timeframe", v.timeframe],
    ["Notes", v.notes],
  ];
  return rows
    .filter(([, val]) => val && val.trim())
    .map(([k, val]) => `${k}: ${val}`)
    .join("\n");
}

/* ============================================================================
 * WEB3FORMS DELIVERY
 * ----------------------------------------------------------------------------
 * Submissions post straight from the browser to Web3Forms, which emails them
 * to the address registered against the access key. No server of our own is
 * involved, which is what lets the whole site be exported as static files.
 *
 * `botcheck` is Web3Forms' honeypot: it is rendered hidden, so a human always
 * leaves it empty and a bot that fills every field gets rejected.
 * ========================================================================== */

const WEB3FORMS_ENDPOINT = "https://api.web3forms.com/submit";

export type SendResult =
  | { ok: true }
  | { ok: false; message: string };

export async function sendToWeb3Forms(payload: {
  accessKey: string;
  subject: string;
  replyTo: string;
  fields: Record<string, string>;
  botcheck: boolean;
}): Promise<SendResult> {
  /* Reject locally too, so an obvious bot never costs a network round trip. */
  if (payload.botcheck) return { ok: false, message: "Submission rejected." };

  try {
    const res = await fetch(WEB3FORMS_ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({
        access_key: payload.accessKey,
        subject: payload.subject,
        from_name: "QMATES website",
        replyto: payload.replyTo,
        botcheck: "",
        ...payload.fields,
      }),
    });

    const data = (await res.json().catch(() => null)) as
      | { success?: boolean; message?: string }
      | null;

    if (res.ok && data?.success) return { ok: true };

    return {
      ok: false,
      message:
        data?.message ??
        `The form could not be sent (error ${res.status}). Please try again, or email the details directly.`,
    };
  } catch {
    return {
      ok: false,
      message:
        "The form could not be sent — you may be offline. Try again, or email the details directly.",
    };
  }
}
