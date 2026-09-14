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
