import { NextResponse } from "next/server";
import { validateContact, type ContactPayload } from "@/lib/enquiry";

/* ============================================================================
 * CONTACT SUBMISSION ENDPOINT
 * Same status as /api/quote: validates and acknowledges, does not send email.
 * See src/app/api/quote/route.ts for the steps to connect a provider.
 * ========================================================================== */

export async function POST(request: Request) {
  let body: Partial<ContactPayload>;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ ok: false, message: "Invalid request body." }, { status: 400 });
  }

  const errors = validateContact(body);
  if (Object.keys(errors).length > 0) {
    return NextResponse.json({ ok: false, errors }, { status: 422 });
  }

  const reference = `C-${Date.now().toString(36).toUpperCase()}`;
  console.log(
    `[contact ${reference}] ${body.name} <${body.email}> — ${body.subject}\n${body.message}`,
  );

  // ---- CONNECT YOUR EMAIL PROVIDER HERE ----------------------------------

  return NextResponse.json({ ok: true, reference, delivered: false });
}
