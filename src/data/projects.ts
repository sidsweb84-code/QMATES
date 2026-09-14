/* ============================================================================
 * PROJECTS
 * ----------------------------------------------------------------------------
 * EVERY ENTRY BELOW IS A SAMPLE / CONCEPT PROJECT, NOT A REAL CLIENT.
 * They exist so the portfolio, gallery and case-study templates are fully
 * built and styled. `isPlaceholder: true` makes the UI label them honestly.
 *
 * TO ADD A REAL PROJECT:
 *   1. Copy any object below.
 *   2. Set `isPlaceholder: false` — the "Sample project" badge disappears.
 *   3. Fill in `outcomes` only with results you can genuinely evidence,
 *      or leave it as `null` and the Results section is omitted entirely.
 *   4. Drop screenshots into /public/work/<slug>/ and set `screenshots`.
 *      While `screenshots` is empty the case study renders the built-in
 *      code-drawn site preview instead, so nothing is ever a broken image.
 * ========================================================================== */

export type ProjectCategory =
  | "Trades"
  | "Hospitality"
  | "Professional Services"
  | "Health"
  | "Retail";

export type PreviewLayout = "hero" | "split" | "editorial" | "grid";

export type ProjectPalette = {
  bg: string;
  surface: string;
  ink: string;
  muted: string;
  accent: string;
  accentInk: string;
};

export type SitePreviewSpec = {
  layout: PreviewLayout;
  nav: string[];
  headline: string;
  headlineAccent?: string;
  sub: string;
  cta: string;
  secondaryCta?: string;
  tiles?: string[];
};

export type Project = {
  slug: string;
  name: string;
  industry: string;
  category: ProjectCategory;
  year: string;
  location: string;
  summary: string;
  intro: string;
  services: string[];
  pages: number;
  challenge: string;
  approach: string;
  designDirection: string;
  features: { title: string; body: string }[];
  mobileNote: string;
  /** null until real, evidenced results exist. Never invent numbers here. */
  outcomes: string[] | null;
  palette: ProjectPalette;
  preview: SitePreviewSpec;
  gallery: { caption: string; layout: PreviewLayout }[];
  /** Real screenshot paths, e.g. "/work/annergy-solar/home.png". */
  screenshots: { src: string; alt: string }[];
  isPlaceholder: boolean;
  featured: boolean;
};

export const projects: Project[] = [
  {
    slug: "coastline-solar",
    name: "Coastline Solar",
    industry: "Solar installation",
    category: "Trades",
    year: "2025",
    location: "Sunshine Coast, QLD",
    summary:
      "A quote-first website for a residential solar installer, built around one question: will this roof pay for itself?",
    intro:
      "Coastline Solar is a sample project showing how QMATES approaches a trades business with a considered sales process and a high-value enquiry.",
    services: ["Website Design", "Website Development", "Enquiry Flow", "Mobile Optimisation"],
    pages: 11,
    challenge:
      "Solar buyers compare four or five installers before they call anyone. The old site listed panel brands and left the visitor to work out the rest, so most enquiries arrived cold and needed a long phone call before anything could be quoted.",
    approach:
      "The entire site was rebuilt around the quote path. A short savings estimator sits in the hero, each system tier has its own page with plain-English inclusions, and every scroll depth has a way to start a quote without losing the reader's place.",
    designDirection:
      "Warm dusk photography against a deep navy base, with a single amber accent reserved exclusively for actions. Long-form technical detail is set in a narrow measure so it stays readable on a phone in a driveway.",
    features: [
      { title: "Roof-size savings estimator", body: "Three inputs, an indicative figure and a direct path into the quote form with the answers carried across." },
      { title: "System tier pages", body: "Each tier gets a real page with inclusions, warranty terms and finance options rather than a comparison table nobody reads." },
      { title: "Installer-side enquiry brief", body: "The form output is structured so the installer can price the job before the first call." },
      { title: "Rebate explainer", body: "A plain-language page covering current incentives, written so it can be updated without a developer." },
    ],
    mobileNote:
      "Most enquiries arrive from a phone. The estimator collapses to a single-column stepper, the call button is thumb-reachable on every screen, and the quote form uses numeric and tel keyboards so nothing has to be typed twice.",
    outcomes: null,
    palette: { bg: "#0d1420", surface: "#141d2d", ink: "#f4f7fb", muted: "#8ea0bb", accent: "#f0a03c", accentInk: "#21150a" },
    preview: {
      layout: "hero",
      nav: ["Home", "Systems", "Savings", "About", "Contact"],
      headline: "Solar, priced",
      headlineAccent: "for your roof.",
      sub: "A system specified for the roof you already have — not a package guessed over the phone.",
      cta: "Get a quote",
      secondaryCta: "Estimate savings",
      tiles: ["6.6kW", "10kW", "13.3kW"],
    },
    gallery: [
      { caption: "Home — hero and savings estimator", layout: "hero" },
      { caption: "System tier detail page", layout: "split" },
      { caption: "Rebate explainer", layout: "editorial" },
    ],
    screenshots: [],
    isPlaceholder: true,
    featured: true,
  },
  {
    slug: "driveway-mechanical",
    name: "Driveway Mechanical",
    industry: "Mobile mechanic",
    category: "Trades",
    year: "2025",
    location: "Logan, QLD",
    summary:
      "A booking-led site for a mobile mechanic, where the whole job is proving you'll actually turn up.",
    intro:
      "Driveway Mechanical is a sample project demonstrating a service-area business whose conversion depends entirely on trust and availability.",
    services: ["Website Design", "Website Development", "Booking Flow", "Local SEO Foundations"],
    pages: 8,
    challenge:
      "A mobile mechanic has no workshop to visit and no shopfront to judge. Every visitor is silently asking whether this is a real business, whether it covers their suburb, and whether it can come out this week.",
    approach:
      "Answer all three above the fold. The service area is stated by name, availability is visible, and the booking form asks for the vehicle and the problem rather than a generic message box.",
    designDirection:
      "High-contrast charcoal with a cool electric accent, heavy condensed headings and a deliberately mechanical grid. Photography is tight and functional — hands and tools, not stock garages.",
    features: [
      { title: "Suburb coverage checker", body: "A visitor types their suburb and gets a yes, a no, or a call-out surcharge, immediately." },
      { title: "Vehicle-aware booking", body: "Make, model and symptom captured up front so the van arrives carrying the right parts." },
      { title: "Service pages per job type", body: "Logbook servicing, brakes, batteries and pre-purchase inspections each get their own indexable page." },
      { title: "Clear pricing bands", body: "Indicative ranges published for common jobs so the first phone call is not about money." },
    ],
    mobileNote:
      "Built phone-first. The coverage checker and the call button sit in the first screen, service pages collapse to accordions, and the booking form remembers entries if the page is backgrounded mid-typing.",
    outcomes: null,
    palette: { bg: "#0a0c0f", surface: "#13171c", ink: "#f1f4f7", muted: "#93a1ae", accent: "#5ad2ff", accentInk: "#04202b" },
    preview: {
      layout: "split",
      nav: ["Home", "Services", "Areas", "Pricing", "Book"],
      headline: "Wheels don't stop.",
      headlineAccent: "Neither do we.",
      sub: "A mobile mechanic that comes to the car, wherever it happens to be sitting.",
      cta: "Book a service",
      secondaryCta: "Check my suburb",
      tiles: ["Logbook", "Brakes", "Batteries"],
    },
    gallery: [
      { caption: "Home — coverage and booking", layout: "split" },
      { caption: "Service detail — logbook servicing", layout: "editorial" },
      { caption: "Pricing bands", layout: "grid" },
    ],
    screenshots: [],
    isPlaceholder: true,
    featured: true,
  },
  {
    slug: "north-quay-kitchen",
    name: "North Quay Kitchen",
    industry: "Restaurant and bar",
    category: "Hospitality",
    year: "2024",
    location: "Brisbane, QLD",
    summary:
      "A menu-and-bookings site for a riverside kitchen, designed for someone deciding where to eat in the next twenty minutes.",
    intro:
      "North Quay Kitchen is a sample project showing how QMATES handles hospitality, where the site is read quickly, usually while walking.",
    services: ["Website Design", "Website Development", "Bookings Integration", "Content Structure"],
    pages: 7,
    challenge:
      "Hospitality sites bury the two things anyone actually wants — the menu and a table. The previous site hid the menu behind a slow PDF that was unreadable on a phone.",
    approach:
      "The menu became real, structured content: searchable, filterable by dietary requirement and updatable by the venue in minutes. Booking sits persistently in the header and never scrolls away.",
    designDirection:
      "A dark, warm room translated to screen — deep olive base, brass accent, generous editorial spacing and a serif used only for dish names. Restrained enough that food photography carries the page.",
    features: [
      { title: "Structured live menu", body: "Dishes as content, not a PDF. Dietary filters, seasonal sections and staff-editable pricing." },
      { title: "Persistent booking", body: "Table booking available from every page without interrupting what the visitor is reading." },
      { title: "Function enquiries", body: "A separate path for group and event bookings so they never get mixed into table requests." },
      { title: "Opening hours source of truth", body: "Hours defined once and reflected across the site, footer and structured data." },
    ],
    mobileNote:
      "The menu is the mobile experience. Sticky category navigation, no pinch-zoom required, and a booking button that stays within thumb reach through the entire scroll.",
    outcomes: null,
    palette: { bg: "#12140d", surface: "#1b1e14", ink: "#f6f4ea", muted: "#a8a68f", accent: "#d8b364", accentInk: "#231a08" },
    preview: {
      layout: "editorial",
      nav: ["Menu", "Bookings", "Functions", "Find us"],
      headline: "River light,",
      headlineAccent: "long lunches.",
      sub: "Seasonal plates and a wine list worth staying for, on the north bank.",
      cta: "Book a table",
      secondaryCta: "See the menu",
      tiles: ["Lunch", "Dinner", "Wine"],
    },
    gallery: [
      { caption: "Home — editorial hero", layout: "editorial" },
      { caption: "Live menu with dietary filters", layout: "grid" },
      { caption: "Functions enquiry", layout: "split" },
    ],
    screenshots: [],
    isPlaceholder: true,
    featured: true,
  },
  {
    slug: "hinterland-physio",
    name: "Hinterland Physio",
    industry: "Physiotherapy clinic",
    category: "Health",
    year: "2024",
    location: "Toowoomba, QLD",
    summary:
      "A calm, accessible clinic site where booking an appointment takes three taps and no phone call.",
    intro:
      "Hinterland Physio is a sample project demonstrating an accessibility-led build for a healthcare practice with an older patient base.",
    services: ["Website Design", "Website Development", "Accessibility", "Website Maintenance"],
    pages: 9,
    challenge:
      "A significant share of patients are over sixty-five and read on tablets at a large system text size. The previous site broke badly at those settings and pushed everyone back to the phone line.",
    approach:
      "Accessibility drove the layout rather than being audited in afterwards: fluid type that survives 200% zoom, no fixed-height containers, full keyboard operation and a booking flow that works entirely without a mouse.",
    designDirection:
      "Soft sage and warm off-white, generous line height and a deliberately unhurried rhythm. Nothing flashes, nothing auto-plays, and the only motion is a gentle fade on entry.",
    features: [
      { title: "Practitioner profiles", body: "Each physio has a real page with focus areas and availability, so patients can choose rather than be assigned." },
      { title: "Condition library", body: "Plain-language pages for common conditions, each ending in the relevant booking path." },
      { title: "Three-tap booking", body: "Practitioner, time, details. No account creation, no phone call required." },
      { title: "Text-scale resilience", body: "Tested to 200% browser zoom and largest system text with no clipping or overlap." },
    ],
    mobileNote:
      "Touch targets exceed 48px throughout, forms use the correct input types, and the layout reflows to a single column well before typical tablet breakpoints so nothing is cramped in portrait.",
    outcomes: null,
    palette: { bg: "#101613", surface: "#18211c", ink: "#f0f5f1", muted: "#9bb0a4", accent: "#7fd6a2", accentInk: "#082214" },
    preview: {
      layout: "split",
      nav: ["Our team", "Conditions", "Fees", "Book"],
      headline: "Move better,",
      headlineAccent: "sooner.",
      sub: "Hands-on physiotherapy in the Toowoomba range, with appointments most weeks.",
      cta: "Book online",
      secondaryCta: "Meet the team",
      tiles: ["Back", "Knee", "Sports"],
    },
    gallery: [
      { caption: "Home — practitioner-led hero", layout: "split" },
      { caption: "Condition library index", layout: "grid" },
      { caption: "Booking flow, step one", layout: "hero" },
    ],
    screenshots: [],
    isPlaceholder: true,
    featured: true,
  },
  {
    slug: "granite-belt-provisions",
    name: "Granite Belt Provisions",
    industry: "Regional produce and cellar door",
    category: "Retail",
    year: "2024",
    location: "Stanthorpe, QLD",
    summary:
      "A small-batch producer's shopfront, where the story does the selling and the checkout stays out of the way.",
    intro:
      "Granite Belt Provisions is a sample project covering a product-led site for a regional producer selling both online and at the gate.",
    services: ["Website Design", "Website Development", "Product Structure", "Website Maintenance"],
    pages: 10,
    challenge:
      "Regional producers compete with supermarket pricing they cannot match. The site has to make provenance legible in seconds, or the visitor reduces the decision to dollars per kilo.",
    approach:
      "Every product is anchored to its grower, season and batch. The checkout was stripped to the minimum number of fields that still capture a regional delivery address correctly.",
    designDirection:
      "Granite grey and dried-grass ochre, photography-forward with a tight editorial grid. Product names set large, prices deliberately quiet.",
    features: [
      { title: "Provenance on every product", body: "Grower, season and batch shown inline rather than buried in a story page nobody clicks." },
      { title: "Cellar door hours", body: "Gate opening times and seasonal closures surfaced prominently, managed in one place." },
      { title: "Regional delivery logic", body: "Address handling that copes with rural delivery realities instead of rejecting them." },
      { title: "Seasonal collections", body: "Collections that rotate with what is actually picked, editable without a developer." },
    ],
    mobileNote:
      "Product imagery crops to a portrait ratio on phones rather than letterboxing, the cart is a bottom sheet, and the checkout is a single scroll with no horizontal input rows.",
    outcomes: null,
    palette: { bg: "#14120f", surface: "#1d1a15", ink: "#f5f2ea", muted: "#aca394", accent: "#c9a227", accentInk: "#201a05" },
    preview: {
      layout: "grid",
      nav: ["Shop", "Growers", "Cellar door", "Journal"],
      headline: "Grown up the",
      headlineAccent: "granite belt.",
      sub: "Small-batch preserves, stone fruit and cool-climate wine, sent from the gate.",
      cta: "Shop provisions",
      secondaryCta: "Visit the gate",
      tiles: ["Preserves", "Stone fruit", "Wine"],
    },
    gallery: [
      { caption: "Home — seasonal collection grid", layout: "grid" },
      { caption: "Product detail with provenance", layout: "split" },
      { caption: "Grower story", layout: "editorial" },
    ],
    screenshots: [],
    isPlaceholder: true,
    featured: true,
  },
  {
    slug: "moreton-legal",
    name: "Moreton Legal",
    industry: "Family and property law",
    category: "Professional Services",
    year: "2023",
    location: "Redcliffe, QLD",
    summary:
      "A quiet, credible site for a small legal practice, rebuilt so first contact feels less like a commitment.",
    intro:
      "Moreton Legal is a sample project showing a professional services build where restraint and clarity carry more weight than visual impact.",
    services: ["Website Redesign", "Website Development", "Content Structure", "SEO Foundations"],
    pages: 12,
    challenge:
      "People contacting a family lawyer are usually having a bad month. The previous site was written for other lawyers — dense, formal, and offering no low-commitment way to start a conversation.",
    approach:
      "Rewritten to a plain-English structure with a clear fee position, then a deliberate low-pressure entry point: a fifteen-minute call that can be requested without explaining the whole situation in a form.",
    designDirection:
      "Near-black with a muted slate accent and a text-forward layout. No stock handshakes, no columns, no glass towers. Typography does all the work.",
    features: [
      { title: "Plain-English practice areas", body: "Each area explained in the language a client would actually use to describe their problem." },
      { title: "Fee transparency page", body: "How fees are structured and what triggers them, stated before anyone has to ask." },
      { title: "Fifteen-minute call request", body: "A short, private, low-commitment first step separate from the full enquiry form." },
      { title: "Resource library", body: "Downloadable checklists that give something useful away before any engagement." },
    ],
    mobileNote:
      "Long-form legal content is set to a comfortable measure with clear section anchors, so a visitor reading on a phone can find the relevant paragraph without pinching or endless scrolling.",
    outcomes: null,
    palette: { bg: "#0b0c0e", surface: "#141619", ink: "#eef0f3", muted: "#98a0ab", accent: "#8fa8c9", accentInk: "#0b1420" },
    preview: {
      layout: "editorial",
      nav: ["Practice areas", "Fees", "About", "Contact"],
      headline: "Clear advice,",
      headlineAccent: "plainly put.",
      sub: "Family and property law on the peninsula, without the billable-hour anxiety.",
      cta: "Request a call",
      secondaryCta: "How fees work",
      tiles: ["Family", "Property", "Wills"],
    },
    gallery: [
      { caption: "Home — text-led hero", layout: "editorial" },
      { caption: "Practice area detail", layout: "split" },
      { caption: "Fee transparency", layout: "hero" },
    ],
    screenshots: [],
    isPlaceholder: true,
    featured: true,
  },
];

export const featuredProjects = projects.filter((p) => p.featured);

export function getProject(slug: string): Project | undefined {
  return projects.find((p) => p.slug === slug);
}

export function adjacentProjects(slug: string) {
  const i = projects.findIndex((p) => p.slug === slug);
  if (i === -1) return { prev: undefined, next: undefined };
  return {
    prev: i > 0 ? projects[i - 1] : projects[projects.length - 1],
    next: i < projects.length - 1 ? projects[i + 1] : projects[0],
  };
}

export const galleryCategories: ProjectCategory[] = [
  "Trades",
  "Hospitality",
  "Professional Services",
  "Health",
  "Retail",
];
