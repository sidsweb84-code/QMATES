# QMATES — Queensland's Online Business Partner

A multipage portfolio and sales website for QMATES, a Queensland web design
business. Built with Next.js 15 (App Router), React 19, Tailwind CSS v4 and
Motion.

---

## Running it locally

```bash
npm install
npm run dev        # http://localhost:3000
```

Other scripts:

```bash
npm run build      # production build
npm run start      # serve the production build
npm run typecheck  # tsc --noEmit
```

Requires Node 18.18+ (developed on Node 22).

---

## Routes

Every item below is a real route with its own URL, its own `<title>` and
meta description, and works when visited directly or refreshed.

| Route | Page |
|---|---|
| `/` | Home |
| `/portfolio` | Portfolio index |
| `/portfolio/[slug]` | Case study (4 prerendered) |
| `/gallery` | Website gallery, filterable + lightbox |
| `/testimonials` | Testimonials |
| `/pricing` | Pricing, add-ons and FAQ |
| `/quote` | Three-step quote request |
| `/about` | About QMATES |
| `/contact` | Contact details + short form |
| `*` | 404 page with full navigation |

Plus `/sitemap.xml`, `/robots.txt`, a generated favicon, and the
`/api/quote` and `/api/contact` submission endpoints.

---

## Where to edit content

All copy that changes regularly lives in `src/data/` — you should not need to
touch a component to update the site's content.

| File | Controls | Placeholders to replace |
|---|---|---|
| `src/data/site.ts` | Business name, tagline, email, phone, location, socials, nav | **Email, phone, domain, socials, ABN** — each marked `// TODO:` |
| `src/data/projects.ts` | Every project and case study | All four are real work — nothing to replace |
| `src/data/testimonials.ts` | Testimonials | All 6 slots are placeholders with no invented names |
| `src/data/pricing.ts` | Plans, add-ons, meeting options, FAQ | Real figures — nothing to replace |
| `src/data/services.ts` | Services, process steps, principles | Real copy — edit freely |

### The portfolio

| Project | Status | Link |
|---|---|---|
| Level Up Wall Repair | `live` | levelupwallrepair.com.au |
| Sumner Smash Repairs | `demo` | Vercel demo |
| Gally's Gutter & Solar | `demo` | Vercel demo |
| QMATES | `live` | this site |

`status` drives how the UI labels each entry, so nothing is ever
misrepresented: `live` and `demo` get a teal badge and an outbound link,
`sample` gets an amber "Sample project" badge. The portfolio page's
explanatory note is generated from the statuses actually present, so it can
never describe a category of work that is not on the page.

Every entry is currently real work — there are no sample projects left.

### Adding a real project

1. Copy any object in `src/data/projects.ts`.
2. Set `status` to `"live"` or `"demo"` and fill `liveUrl` + `liveLabel`.
3. Only fill `outcomes` with results you can evidence. Leave it `null` and
   the Results section explains that no results are published, rather than
   inventing any.
4. For real screenshots, drop images into `public/work/<slug>/` and list them
   in `screenshots`. While that array is empty the case study renders the
   built-in code-drawn preview instead, so nothing is ever a broken image.
5. `preview: null` + `palette: null` means "no mockup yet" — the card and case
   study say so plainly and link to the live site instead of inventing one.
   Nothing uses this right now, but it is there so an entry can be added
   before its write-up exists.
6. `palette.accent2` is optional. Set it when a site deliberately colours two
   primary actions differently (Gally's uses green for the quote form and
   amber for the phone) and the mockup will reproduce that hierarchy.

### Adding a real testimonial

Set `isPlaceholder: false` and fill `quote`, `author`, `role` and `business`.
Use the client's own words. Any slot left as a placeholder renders with a
visible "Awaiting client quote" marker, so unreplaced content can never be
mistaken for a real endorsement.

---

## Connecting email delivery — READ THIS

**The forms do not send email yet.** No provider is configured, so:

- `POST /api/quote` and `POST /api/contact` validate the submission
  server-side, log it, and return a reference — with `delivered: false`.
- The success screens say plainly that nothing has been emailed, and offer a
  pre-filled `mailto:` carrying the full submission so the enquiry still
  reaches a person today.

To connect real delivery:

1. `npm install resend` (or Postmark, SendGrid, Nodemailer — anything).
2. Put the key in `.env.local` as `QUOTE_EMAIL_KEY`. Never commit it.
3. Send `summary` to `site.email` in the marked block in
   `src/app/api/quote/route.ts`, and do the same in `api/contact/route.ts`.
4. Change the response to `delivered: true`.
5. The "not emailed" notices in `QuoteForm.tsx` and `ContactForm.tsx` are
   already conditional on that flag and will disappear on their own.

---

## Design system

Tokens live in one place: `src/app/globals.css`, under `@theme`.

- **Canvas** — near-black ink (`#06090a`) with raised surfaces.
- **Accents** — reef aqua `#37d9be` (primary, 11.2:1 on the canvas) and warm
  sand `#e9c99b` (secondary, reserved for placeholder and caution markers).
- **Type** — Bricolage Grotesque (display), DM Sans (body/UI), Instrument
  Serif italic (single accent words only). Self-hosted via `next/font`.
- **Radii** are deliberately restrained (2/4/8/14/22px) rather than a blanket
  pill shape.
- **Motion** — shared easing and duration tokens; every animation respects
  `prefers-reduced-motion`.

### Two rules worth knowing before editing components

Both are documented in the files that enforce them:

1. **Never branch the rendered tree on `useReducedMotion()`** — it resolves
   `false` on the server and `true` after mount, which causes a hydration
   mismatch for every visitor with reduced motion enabled. Reduction is
   handled by `<MotionConfig reducedMotion="user">` in the root layout plus a
   CSS guard on `[data-reveal]`. See `src/components/ui/Reveal.tsx`.
2. **Never call `motion.create()` inside a render** — it returns a new
   component type each render and remounts the subtree. `Reveal.tsx` caches
   them at module scope.

---

## Notable components

| Component | What it does |
|---|---|
| `site/SitePreview.tsx` | Renders a **miniature website** in markup and CSS from a project's palette. Used for cards, gallery, case studies and the hero. Sized entirely in container-query units, so one component scales from a thumbnail to a full-width hero. Also exports `MobileSitePreview`, `BrowserFrame` and `PhoneFrame`. |
| `site/HomeHero.tsx` | Animated portfolio stack — a phone in front of a browser window, both stepping through featured projects, with dot controls and a pause toggle. |
| `site/QuoteForm.tsx` | Three-step form: per-step validation, focusable error summary, loading and success states. |
| `site/GalleryGrid.tsx` | Masonry gallery with industry filtering and a keyboard-operable lightbox. |
| `ui/Button.tsx` | Five variants, each with a different hover mechanic. |
| `ui/Field.tsx` | Accessible inputs, selects, radio cards and checkbox chips. |
| `ui/Reveal.tsx` | Scroll-entry and stagger animations. |

### Why the previews are drawn in code

There are no captured screenshots of the live sites in the repo yet. A
code-drawn preview is honest — it is a design mockup built from each site's
real palette, headline, navigation and calls to action, not a photograph
passed off as one. It weighs nothing, stays sharp at any size, and can never
404. When real screenshots arrive they take over automatically — see "Adding a
real project" above.

---

## What was verified

Checked with headless Chromium against the production build:

- All 10 routes return the correct status at 320 / 360 / 390 / 430 / 600 /
  768 / 820 / 1024 / 1280 / 1440 / 1920px, and work on direct navigation.
- No console errors, no broken images, no unnamed links or buttons.
- Exactly one `<h1>` per page, no skipped heading levels, meta description on
  every page.
- No horizontally clipped text at any tested width.
- Mobile menu: opens, locks scroll, closes on Escape and on navigation,
  restores focus and scroll.
- Quote form: blocks on invalid input, focuses the error summary, validates
  email inline on blur, sets `aria-invalid`, advances all three steps,
  submits, and produces a working `mailto` fallback.
- Gallery: filtering (24 → 4 items), lightbox open/close, arrow-key
  navigation, Escape to close, scroll restored.
- Keyboard: first tab stop is the skip link, 2px focus ring, 25 consecutive
  tab stops all land on visible elements.
- Reduced motion: no hydration mismatch, no content left faded out, full
  gallery renders.

Two inline links (`hello@qmates.com.au` in the closing CTA and "Send it
through" on the testimonials page) are under 24×24px. Both sit inside a
sentence, which is the documented exception in WCAG 2.2 SC 2.5.8.

---

## Still needed from you

1. **The production domain** (`site.url`) so canonical URLs, Open Graph tags
   and the sitemap point somewhere real.
2. **Real screenshots**, if you want photographs of the live sites instead of
   the code-drawn mockups.
3. **Real testimonials**, in clients' own words.
4. **Real pricing** to replace the `$XXX` placeholders.
5. **An email provider** so the forms actually deliver.
6. **Socials and ABN** in `src/data/site.ts`, if you want them in the footer.
7. Optional: a logo file. The current mark is drawn in
   `src/components/ui/Icon.tsx` and matches `src/app/icon.svg`.

> Contact details are set to **0472 747 757** and **sidsweb84@gmail.com**. The
> address supplied was `sidsweb84@gmail.com.au`; there is no `gmail.com.au`
> mail domain, so that was corrected to the near-certain intent. Change it in
> `src/data/site.ts` if the original was deliberate.
