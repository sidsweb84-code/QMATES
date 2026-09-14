/* ============================================================================
 * PRICING
 * ----------------------------------------------------------------------------
 * Real figures. Ranges are the honest starting point — every plan is slightly
 * negotiable depending on the state of the business, which is what
 * `negotiableNote` says on the page.
 * ========================================================================== */

export type Plan = {
  id: string;
  name: string;
  price: string;
  priceNote: string;
  audience: string;
  description: string;
  /** Page allowance. */
  pages: string;
  /** Post-launch support window. */
  support: string;
  includes: string[];
  /** Rendered as a caveat under the inclusions, not as a struck-through list. */
  excludes?: string[];
  cta: string;
  highlighted: boolean;
};

export const plans: Plan[] = [
  {
    id: "booster",
    name: "Booster",
    price: "$300–400",
    priceNote: "one-off",
    audience: "Businesses updating or upgrading a site they already have",
    description:
      "You have a website. It works, but it looks dated, moves badly or does not take enquiries properly. Booster lifts what is already there rather than starting again.",
    pages: "Your existing site, plus extra pages",
    support: "For as long as you want it",
    includes: [
      "Upgrade of your existing website",
      "Animations and considered font pairings",
      "Extra pages added",
      "A working quote system",
      "Your current domain linked, and hosted free",
      "Post-launch support for as long as you would like",
      "Full back end and code handed over on GitHub",
      "Profile guidance — new email or phone number promotion or reinstatement",
      "Photo update, or a gallery page installed",
    ],
    cta: "Start with Booster",
    highlighted: false,
  },
  {
    id: "starter",
    name: "Starter",
    price: "$400–500",
    priceNote: "one-off",
    audience: "Businesses that need a proper website built from scratch",
    description:
      "A complete site built from nothing — designed for your business, built by hand, and set up so customers can actually reach you.",
    pages: "Up to 5+ pages",
    support: "Up to 6 months",
    includes: [
      "Up to 5+ pages",
      "Free hosting",
      "Interactive, working photos and animations",
      "Google Business and profile guidance",
      "Phone number and email promotion",
      "Up to 6 months post-launch support",
    ],
    excludes: [
      "Domain not included — either purchased and set up by you, or set up by QMATES for a fee",
    ],
    cta: "Start with Starter",
    highlighted: false,
  },
  {
    id: "growth",
    name: "Customised Growth & Automation",
    price: "From $500",
    priceNote: "quoted per business, plus ~$20/month",
    audience: "Businesses that want the site to keep working for them",
    description:
      "Everything built, everything set up, everything maintained. Quoted against what your business actually needs rather than squeezed into a package.",
    pages: "As many pages as you want",
    support: "Constant and ongoing",
    includes: [
      "As many pages as the business wants",
      "Fully interactive, customised and animated website",
      "Google Business and profile guidance",
      "Phone number and email promotion",
      "Working quotes and service pages",
      "Before-and-after sliders plus a gallery page",
      "Domain and hosting paid for and set up by QMATES",
      "Infinite, constant post-launch support",
    ],
    cta: "Discuss a custom plan",
    highlighted: true,
  },
];

export const negotiableNote =
  "All plans are slightly negotiable depending on the state of the business and what we agree on. Figures are in AUD.";

export type AddOn = { name: string; price: string; note: string };

export const addOns: AddOn[] = [
  {
    name: "Domain + forms linking",
    price: "$100",
    note: "plus $25 for any extra labour needed — for example, pages added beyond your chosen plan",
  },
  {
    name: "Extra pages",
    price: "$25",
    note: "per page, from three months after launch",
  },
  {
    name: "Maintenance",
    price: "$50/hr",
    note: "theme colour changes, personal requests and bug fixing — usually only an hour",
  },
];

export type Meeting = { title: string; who: string; body: string };

export const meetings: Meeting[] = [
  {
    title: "In person",
    who: "Businesses in and around Brisbane",
    body: "We meet at either Toowong or Indooroopilly library — somewhere neutral, quiet and easy to park at.",
  },
  {
    title: "Remote",
    who: "Businesses further out or interstate",
    body: "Zoom or over the phone, whichever suits you, along with a drafted contract so both sides are covered before anything starts.",
  },
];

export type Faq = { q: string; a: string };

export const pricingFaqs: Faq[] = [
  {
    q: "Which plan do I need?",
    a: "If you already have a website and it needs lifting, that is Booster. If you have nothing and need a proper site built, that is Starter. If you want the site to keep working for you — quotes, galleries, automation and ongoing changes — that is the customised plan.",
  },
  {
    q: "Are the prices negotiable?",
    a: "Slightly, yes. Every plan moves a little depending on the state of the business and what we agree on. The ranges shown are an honest starting point rather than a headline figure designed to get you on the phone.",
  },
  {
    q: "What is the monthly fee on the customised plan?",
    a: "Around $20 a month. It covers the domain and hosting, both paid for and set up by QMATES, plus the constant post-launch support that plan includes. It is quoted with the rest of the project so you see it before you commit.",
  },
  {
    q: "Is the domain included?",
    a: "On the customised plan, yes — domain and hosting are paid for and set up by QMATES. On Starter it is not: you either buy and set it up yourself, or QMATES sets it up for a fee. Booster links the domain you already have.",
  },
  {
    q: "Do I own the website?",
    a: "Yes. On Booster the full back end and code are handed to you on GitHub. On every plan the site is yours — nothing is held hostage, and moving on is always possible.",
  },
  {
    q: "What happens after launch?",
    a: "Booster and the customised plan include post-launch support for as long as you want it. Starter includes up to six months. After that, maintenance is $50 an hour — usually only an hour — and extra pages are $25 each.",
  },
];

/** Prices above are real. Kept so the UI can flag placeholder pricing again. */
export const pricesArePlaceholder = false;
