/* ============================================================================
 * SERVICES & PROCESS
 * Edit freely — the home page, about page and quote form all read from here.
 * ========================================================================== */

export type Service = {
  id: string;
  index: string;
  title: string;
  summary: string;
  detail: string;
  includes: string[];
};

export const services: Service[] = [
  {
    id: "design",
    index: "01",
    title: "Website Design",
    summary:
      "A considered design built around how your customers actually decide, not around a template's demo content.",
    detail:
      "Layout, typography, colour and imagery chosen for your business specifically. You see real designs with your own content in them before anything gets built.",
    includes: ["Design direction", "Page-by-page layouts", "Mobile designs", "Two revision rounds"],
  },
  {
    id: "development",
    index: "02",
    title: "Website Development",
    summary:
      "Hand-built, fast and stable. No page-builder bloat, no plugin stack that breaks on update.",
    detail:
      "Clean, modern code with proper semantics and accessibility, built to load quickly on a phone connection anywhere in Queensland.",
    includes: ["Responsive build", "Accessibility pass", "Performance budget", "Browser testing"],
  },
  {
    id: "business",
    index: "03",
    title: "Business Websites",
    summary:
      "The complete package for a business that needs to look established and take enquiries reliably.",
    detail:
      "Everything from structure and copy guidance through to contact forms, service pages and the details that make a small business read as a serious one.",
    includes: ["Site structure", "Service pages", "Enquiry forms", "Google Business setup guidance"],
  },
  {
    id: "redesign",
    index: "04",
    title: "Website Redesigns",
    summary:
      "You already have a site. It looks dated, loads slowly, or nobody enquires through it.",
    detail:
      "A redesign starts with working out what is actually failing — presentation, structure or trust — then rebuilds only what needs rebuilding.",
    includes: ["Current-site review", "Structure rework", "Full rebuild", "Redirect mapping"],
  },
  {
    id: "mobile",
    index: "05",
    title: "Mobile Optimisation",
    summary:
      "Most of your visitors are on a phone. That is the design that matters most.",
    detail:
      "Mobile is designed deliberately, not shrunk down from desktop — proper touch targets, thumb-reachable actions and layouts built for a small screen.",
    includes: ["Mobile-first layouts", "Touch target audit", "Speed on mobile data", "Real-device testing"],
  },
  {
    id: "maintenance",
    index: "06",
    title: "Website Maintenance",
    summary:
      "Ongoing care so the site stays fast, current and online — without you thinking about it.",
    detail:
      "Updates, backups, monitoring and small content changes handled on an ongoing basis, with a clear monthly scope.",
    includes: ["Content updates", "Uptime monitoring", "Backups", "Monthly check-in"],
  },
];

export type ProcessStep = {
  index: string;
  title: string;
  body: string;
  detail: string[];
};

export const process: ProcessStep[] = [
  {
    index: "01",
    title: "Discover",
    body: "We work out what the site actually has to do before anyone talks about how it should look.",
    detail: ["Business and customer questions", "Competitor review", "Site structure and page list", "Fixed scope and quote"],
  },
  {
    index: "02",
    title: "Design",
    body: "You see real designs with your content in them — desktop and mobile — and we refine from there.",
    detail: ["Design direction", "Key page designs", "Mobile designs", "Revisions until it is right"],
  },
  {
    index: "03",
    title: "Build",
    body: "The approved design gets hand-built, tested properly, and checked on real devices.",
    detail: ["Responsive build", "Forms and integrations", "Accessibility and performance", "Cross-browser testing"],
  },
  {
    index: "04",
    title: "Launch",
    body: "We go live carefully, then make sure you know how to run it yourself.",
    detail: ["Domain and hosting setup", "Analytics and search setup", "Handover walkthrough", "Post-launch support window"],
  },
];

export type Principle = { title: string; body: string };

export const principles: Principle[] = [
  {
    title: "You talk to the person building it",
    body: "There is no account manager relaying messages. The person you brief is the person designing and writing the code.",
  },
  {
    title: "Fixed scope, fixed price",
    body: "You get a written scope and a fixed figure before work starts. If the scope changes, you approve the change first.",
  },
  {
    title: "Built to be handed over",
    body: "You own the domain, the hosting account and the site. Nothing is held hostage, and leaving is always possible.",
  },
  {
    title: "Fast by default",
    body: "Performance is a design constraint from the first day, not an optimisation pass bolted on at the end.",
  },
];

/* ============================================================================
 * HOME FAQ
 * Short answers to what people ask before they enquire. Anything needing a
 * long answer belongs on /pricing or /about, not here.
 * ========================================================================== */

export type HomeFaq = { q: string; a: string };

export const homeFaqs: HomeFaq[] = [
  {
    q: "Who will I be working with?",
    a: "Me, start to finish. The person you brief designs it, writes the code and hands it over — no account manager in between, nothing outsourced.",
  },
  {
    q: "What does it cost?",
    a: "Booster $300–400, Starter $400–500, or a customised plan from $500. Slightly negotiable depending on your business. Full breakdown on the pricing page.",
  },
  {
    q: "Can you improve my existing website?",
    a: "Yes — that is what Booster is for. Animations, extra pages, a working quote system, and your current domain linked and hosted free.",
  },
  {
    q: "Do I own the finished website?",
    a: "Yes. The domain, the hosting and the site are all in your name. On Booster the code comes to you on GitHub.",
  },
  {
    q: "How do we get started?",
    a: "Send a quote request. You get a fixed written figure back within two business days — no obligation, no sales call unless you want one.",
  },
];
