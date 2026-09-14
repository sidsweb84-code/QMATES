import { NextResponse } from "next/server";
import { formatQuote, validateQuote, type QuotePayload } from "@/lib/enquiry";

/* ============================================================================
 * QUOTE SUBMISSION ENDPOINT
 * ----------------------------------------------------------------------------
 * STATUS: validates and acknowledges the submission. IT DOES NOT SEND EMAIL.
 * No email provider is configured in this project, so the route deliberately
 * does not claim delivery — the UI tells the visitor the same thing and offers
 * a mailto fallback carrying the full submission.
 *
 * TO CONNECT DELIVERY:
 *   1. Add a provider dependency (Resend, Postmark, SendGrid, Nodemailer…).
 *   2. Put the API key in .env.local as QUOTE_EMAIL_KEY (never commit it).
 *   3. Send `summary` to site.email in the marked block below.
 *   4. Set `delivered: true` in the response.
 *   5. Remove the "delivery not connected" notice in QuoteForm.tsx.
 * ========================================================================== */

export async function POST(request: Request) {
  let body: Partial<QuotePayload>;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ ok: false, message: "Invalid request body." }, { status: 400 });
  }

  /* Same rules the client applies — never trust the client's own check. */
  const errors = validateQuote(body);
  if (Object.keys(errors).length > 0) {
    return NextResponse.json({ ok: false, errors }, { status: 422 });
  }

  const payload: QuotePayload = {
    name: body.name ?? "",
    business: body.business ?? "",
    email: body.email ?? "",
    phone: body.phone ?? "",
    businessType: body.businessType ?? "",
    existingSite: body.existingSite ?? "",
    projectType: body.projectType ?? "",
    pages: body.pages ?? "",
    features: body.features ?? [],
    budget: body.budget ?? "",
    timeframe: body.timeframe ?? "",
    notes: body.notes ?? "",
  };

  const summary = formatQuote(payload);
  const reference = `Q-${Date.now().toString(36).toUpperCase()}`;

  // Visible in the server log so nothing is silently lost before delivery is wired.
  console.log(`[quote ${reference}]\n${summary}`);

  // ---- CONNECT YOUR EMAIL PROVIDER HERE ----------------------------------
  // await resend.emails.send({ to: site.email, subject: `Quote request ${reference}`, text: summary });
  // ------------------------------------------------------------------------

  return NextResponse.json({
    ok: true,
    reference,
    /* Honest flag: the UI renders a different success state based on this. */
    delivered: false,
    summary,
  });
}
