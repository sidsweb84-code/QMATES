/* ============================================================================
 * PROJECTS
 * ----------------------------------------------------------------------------
 * `status` decides how the UI labels each entry, so nothing is ever
 * misrepresented:
 *   "live"   — a real site, currently online. `liveUrl` is linked.
 *   "demo"   — a real build published as a demo. `liveUrl` is linked.
 *   "sample" — a concept build, not a real client. Labelled in the UI.
 *
 * `preview: null` means there is no mockup for this entry yet — the card and
 * case study say so plainly and link straight to the live site instead of
 * showing an invented screenshot.
 *
 * TO ADD REAL SCREENSHOTS: drop images into /public/work/<slug>/ and list them
 * in `screenshots`. While that array is empty the code-drawn preview is used,
 * so nothing is ever a broken image.
 * ========================================================================== */

export type ProjectCategory =
  | "Trades"
  | "Automotive"
  | "Hospitality"
  | "Professional Services"
  | "Web Design";

export type ProjectStatus = "live" | "demo" | "sample";
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
  status: ProjectStatus;
  /** Display form of the URL, e.g. "levelupwallrepair.com.au". */
  liveLabel: string | null;
  liveUrl: string | null;
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
  palette: ProjectPalette | null;
  preview: SitePreviewSpec | null;
  gallery: { caption: string; layout: PreviewLayout }[];
  screenshots: { src: string; alt: string }[];
  featured: boolean;
};

export const projects: Project[] = [
  /* ---------------------------------------------------------------------- */
  {
    slug: "level-up-wall-repair",
    name: "Level Up Wall Repair",
    industry: "Wall & ceiling repair",
    category: "Trades",
    year: "2025",
    location: "Brisbane, QLD",
    status: "live",
    liveLabel: "levelupwallrepair.com.au",
    liveUrl: "https://levelupwallrepair.com.au",
    summary:
      "A quote-first site for a Brisbane wall and ceiling repairer, built so a photo of the damage is all it takes to start a job.",
    intro:
      "Level Up Wall Repair fixes holes, cracks, water damage and cornice across Brisbane. The site had one job: convert someone standing in front of a damaged wall, phone in hand, into a booked repair.",
    services: [
      "Website Design",
      "Website Development",
      "Quote Flow",
      "Reviews Integration",
      "Mobile Optimisation",
    ],
    pages: 6,
    challenge:
      "Small repair jobs live or die on speed and trust. Someone with a hole in their wall wants to know two things immediately — will this business take a job this small, and what will it cost. A generic trade site answers neither, so every enquiry turns into a long phone call before anything can be priced.",
    approach:
      "The whole site is built around the quote. The hero answers the small-jobs question in the first line, a photo-upload quote form sits at the end of every path, and the 4.9-star Google rating is surfaced in the top bar so credibility arrives before the pitch does.",
    designDirection:
      "Warm cream rather than the usual trade-site white, with a bronze accent reserved strictly for actions and a serif display face — the italic gold second line in the hero gives a repair business a considered, premium feel that its competitors do not have.",
    features: [
      {
        title: "Photo-upload quote form",
        body: "Drag and drop up to six images of the damage. The repairer can scope and price the job before picking up the phone, which is the whole difference between a lead and a quote.",
      },
      {
        title: "Filterable Google reviews",
        body: "All 70 reviews on the page, filterable by job type — wall repair, ceiling, cornice, water damage, patching — with the owner's replies shown alongside. Proof a visitor can search rather than scroll.",
      },
      {
        title: "Small-jobs positioning",
        body: "\"Small Jobs Welcome\" runs through the hero, the trust chips and the contact page, because the most common reason someone does not call a trade is assuming they will be turned away.",
      },
      {
        title: "Preferred contact method",
        body: "Phone, email or text, chosen by the customer on the form. A small field that measurably raises reply rates for trades work.",
      },
    ],
    mobileNote:
      "Almost every enquiry starts on a phone, usually while standing at the damage. The call button sits in the top bar on every screen, the quote form uses tel and email keyboards, and the photo upload goes straight to the camera roll.",
    outcomes: null,
    palette: {
      bg: "#f8f5ef",
      surface: "#efeae0",
      ink: "#23262b",
      muted: "#6f747b",
      accent: "#a9762a",
      accentInk: "#ffffff",
    },
    preview: {
      layout: "split",
      nav: ["Home", "Services", "Gallery", "Reviews", "About", "Contact"],
      headline: "Wall Damage?",
      headlineAccent: "We'll Fix It.",
      sub: "Specialists in small wall and ceiling repairs across Brisbane — holes, cracks, water damage and cornice.",
      cta: "Get a Free Quote",
      secondaryCta: "Call now",
      tiles: ["4.9/5 · 70 Reviews", "Small Jobs Welcome", "Brisbane Based"],
    },
    gallery: [
      { caption: "Home — hero and trust signals", layout: "split" },
      { caption: "Reviews — 70 reviews, filterable by job type", layout: "grid" },
      { caption: "Contact — photo-upload quote form", layout: "editorial" },
    ],
    screenshots: [],
    featured: true,
  },

  /* ---------------------------------------------------------------------- */
  {
    slug: "sumner-smash-repairs",
    name: "Sumner Smash Repairs",
    industry: "Smash repairs & panel beating",
    category: "Automotive",
    year: "2025",
    location: "Sumner, Brisbane QLD",
    status: "demo",
    liveLabel: "View the demo",
    liveUrl: "https://sumnerdemo-egxldgbvm-sids-web.vercel.app/",
    summary:
      "A dark, high-impact build for a Brisbane smash repairer, designed for someone who has just had a bad morning.",
    intro:
      "Sumner Smash Repairs is a demo build for a panel and paint workshop in Sumner. Everyone arriving on this site has just had an accident — the design had to be calm and direct rather than salesy.",
    services: [
      "Website Design",
      "Website Development",
      "Enquiry Flow",
      "Mobile Optimisation",
    ],
    pages: 6,
    challenge:
      "Smash repair is a distress purchase. The visitor is stressed, often dealing with an insurer, and comparing two or three workshops in a hurry. Most repairer sites lead with equipment lists and certifications, which answers none of what that person is actually anxious about.",
    approach:
      "Lead with the outcome, not the process — \"We'll get you back on the road\" — then answer the three real questions immediately: are you nearby, will you tell me the truth, and how do I start. The stats bar puts the rating, the review count and an explicit \"0% pressure sales\" promise directly under the hero.",
    designDirection:
      "Near-black with a single high-voltage red, heavy condensed uppercase display type and a faint diagonal grid — automotive without resorting to chrome or carbon-fibre clichés. The red is spent only on actions and the one word that matters in each heading.",
    features: [
      {
        title: "Incident-led enquiry form",
        body: "\"Tell us what happened\" rather than a contact form: name, phone, vehicle make and model, and a plain description of the damage — everything needed to come back with real advice.",
      },
      {
        title: "Workshop details up front",
        body: "Address, opening hours including Saturday-by-appointment, and a call button, all in one panel beside the form so nobody has to hunt for them.",
      },
      {
        title: "Honest-advice positioning",
        body: "\"0% pressure sales\" sits in the stats row beside the Google rating. For a distress purchase, the absence of a hard sell is the strongest thing you can promise.",
      },
      {
        title: "Our Work gallery",
        body: "Repair work shown as evidence rather than decoration, which is what a nervous customer is really scanning for.",
      },
    ],
    mobileNote:
      "Built for someone standing beside a damaged car. The call button is reachable from any scroll position, the form uses tel and email keyboards, and the heavy display type stays legible in bright sun.",
    outcomes: null,
    palette: {
      bg: "#0b0b0d",
      surface: "#15161a",
      ink: "#ffffff",
      muted: "#9a9ba1",
      accent: "#e63329",
      accentInk: "#ffffff",
    },
    preview: {
      layout: "hero",
      nav: ["Home", "About Us", "Our Work", "Services", "Reviews", "Contact"],
      headline: "Smashed? We'll get you",
      headlineAccent: "back on the road.",
      sub: "Professional smash repairs with honest advice, quality workmanship and service you can trust.",
      cta: "Get a quote",
      secondaryCta: "Call the team",
      tiles: ["4.8 Google Rating", "42+ Reviews", "0% Pressure Sales"],
    },
    gallery: [
      { caption: "Home — hero and stats bar", layout: "hero" },
      { caption: "Contact — incident-led enquiry form", layout: "editorial" },
      { caption: "Our Work — repair gallery", layout: "grid" },
    ],
    screenshots: [],
    featured: true,
  },

  /* ---------------------------------------------------------------------- */
  {
    slug: "qmates",
    name: "QMATES",
    industry: "Web design studio",
    category: "Web Design",
    year: "2026",
    location: "Brisbane, QLD",
    status: "live",
    liveLabel: "You are on it",
    liveUrl: null,
    summary:
      "This site. A studio portfolio where the website itself has to be the strongest thing in the portfolio.",
    intro:
      "The site you are reading. A web designer's own site is the one piece of work every prospective client inspects properly, so it was built to the standard the portfolio claims rather than to a deadline.",
    services: [
      "Website Design",
      "Website Development",
      "Quote Flow",
      "Accessibility",
      "SEO Foundations",
    ],
    pages: 9,
    challenge:
      "A portfolio site has a circular problem: it is simultaneously the argument and the evidence. Anything less than excellent undermines every claim made on it, and a template would end the conversation before the work is even seen.",
    approach:
      "Nine real routes rather than one long scrolling page, every project reachable at its own URL, and a three-step quote flow that asks the questions needed to return a fixed figure instead of a list of follow-up questions.",
    designDirection:
      "A near-black canvas with reef aqua and warm sand — coastal Queensland without the tourism clichés. Bricolage Grotesque for display, DM Sans for reading, and an italic serif spent on exactly one word per heading.",
    features: [
      {
        title: "Previews drawn in code",
        body: "Every project mockup on this site is rendered in markup and CSS from that project's own palette, sized in container-query units. Nothing to download, sharp at any size, and it cannot 404.",
      },
      {
        title: "Three-step quote flow",
        body: "Per-step validation, an error summary that takes keyboard focus, inline validation on blur, and honest loading and success states.",
      },
      {
        title: "Accessibility as a constraint",
        body: "Full keyboard operation, a visible focus ring throughout, one h1 per page with no skipped heading levels, and every animation disabled under prefers-reduced-motion.",
      },
      {
        title: "Verified, not assumed",
        body: "Checked with a headless browser across eleven viewport widths — status codes, console errors, heading order and horizontal overflow on every route.",
      },
    ],
    mobileNote:
      "The phone layout is designed, not shrunk. The navigation becomes a full-screen panel with numbered rows, the portfolio grid stacks to a single readable column, and no page scrolls sideways at any width from 320px up.",
    outcomes: null,
    palette: {
      bg: "#06090a",
      surface: "#101618",
      ink: "#f3f6f5",
      muted: "#9daaab",
      accent: "#37d9be",
      accentInk: "#04211c",
    },
    preview: {
      layout: "editorial",
      nav: ["Home", "Portfolio", "Gallery", "Pricing", "About", "Contact"],
      headline: "Queensland's online",
      headlineAccent: "business partner.",
      sub: "Websites that make Queensland businesses impossible to ignore.",
      cta: "Get a Quote",
      secondaryCta: "View my work",
      tiles: ["Hand-coded", "Mobile-first", "Fixed scope"],
    },
    gallery: [
      { caption: "Home — animated portfolio stack", layout: "editorial" },
      { caption: "Portfolio — every project, its own route", layout: "split" },
      { caption: "Quote — three-step request flow", layout: "hero" },
    ],
    screenshots: [],
    featured: true,
  },

  /* ---------------------------------------------------------------------- */
  {
    slug: "gally-gutter",
    name: "Gally Gutter",
    industry: "Guttering",
    category: "Trades",
    year: "2025",
    location: "Brisbane, QLD",
    status: "demo",
    liveLabel: "View the demo",
    liveUrl: "https://samplegallygutter.vercel.app/",
    summary:
      "A guttering demo build. The write-up and preview for this one are still to come — the live demo is one click away.",
    intro:
      "A demo build for a guttering business. The case study below has not been written up yet, so rather than fill it with invented detail the live demo is linked directly.",
    services: ["Website Design", "Website Development"],
    pages: 0,
    challenge: "",
    approach: "",
    designDirection: "",
    features: [],
    mobileNote: "",
    outcomes: null,
    palette: null,
    preview: null,
    gallery: [],
    screenshots: [],
    featured: true,
  },

  /* ---------------------------------------------------------------------- */
  {
    slug: "north-quay-kitchen",
    name: "North Quay Kitchen",
    industry: "Restaurant and bar",
    category: "Hospitality",
    year: "2024",
    location: "Brisbane, QLD",
    status: "sample",
    liveLabel: null,
    liveUrl: null,
    summary:
      "A concept build for a riverside kitchen, designed for someone deciding where to eat in the next twenty minutes.",
    intro:
      "North Quay Kitchen is a sample project — not a real client — showing how QMATES approaches hospitality, where the site is read quickly and usually while walking.",
    services: [
      "Website Design",
      "Website Development",
      "Bookings Integration",
      "Content Structure",
    ],
    pages: 7,
    challenge:
      "Hospitality sites bury the two things anyone actually wants — the menu and a table. The usual culprit is a slow PDF menu that is unreadable on a phone.",
    approach:
      "The menu becomes real, structured content: searchable, filterable by dietary requirement and updatable by the venue in minutes. Booking sits persistently in the header and never scrolls away.",
    designDirection:
      "A dark, warm room translated to screen — deep olive base, brass accent, generous editorial spacing and a serif used only for dish names. Restrained enough that food photography carries the page.",
    features: [
      {
        title: "Structured live menu",
        body: "Dishes as content, not a PDF. Dietary filters, seasonal sections and staff-editable pricing.",
      },
      {
        title: "Persistent booking",
        body: "Table booking available from every page without interrupting what the visitor is reading.",
      },
      {
        title: "Function enquiries",
        body: "A separate path for group and event bookings so they never get mixed into table requests.",
      },
      {
        title: "Opening hours source of truth",
        body: "Hours defined once and reflected across the site, footer and structured data.",
      },
    ],
    mobileNote:
      "The menu is the mobile experience. Sticky category navigation, no pinch-zoom required, and a booking button that stays within thumb reach through the entire scroll.",
    outcomes: null,
    palette: {
      bg: "#12140d",
      surface: "#1b1e14",
      ink: "#f6f4ea",
      muted: "#a8a68f",
      accent: "#d8b364",
      accentInk: "#231a08",
    },
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
    featured: true,
  },
];

export const featuredProjects = projects.filter((p) => p.featured);

/** Projects with a mockup — the gallery and hero rotator can only use these. */
export const previewableProjects = projects.filter((p) => p.preview && p.palette);

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

/** The address shown in mockup browser chrome. Never invent a domain for a
 *  project whose real URL is known. */
export function displayUrl(project: Project): string {
  if (project.liveUrl) {
    try {
      return new URL(project.liveUrl).host;
    } catch {
      return project.liveUrl;
    }
  }
  return `${project.slug}.com.au`;
}

export const STATUS_LABEL: Record<ProjectStatus, string> = {
  live: "Live site",
  demo: "Demo build",
  sample: "Sample project",
};
