/* ============================================================================
 * PRICING
 * ----------------------------------------------------------------------------
 * ALL PRICES BELOW ARE PLACEHOLDERS.
 *
 * TO PUBLISH REAL PRICING:
 *   1. Replace each `price` string with your real figure, e.g. "$2,450".
 *   2. Set `pricesArePlaceholder` to false at the bottom of this file.
 *      The "indicative placeholder" notice on /pricing then disappears.
 * ========================================================================== */

export type Plan = {
  id: string;
  name: string;
  price: string;
  priceNote: string;
  audience: string;
  description: string;
  pages: string;
  timeline: string;
  includes: string[];
  excludes?: string[];
  cta: string;
  highlighted: boolean;
};

export const plans: Plan[] = [
  {
    id: "starter",
    name: "Starter",
    price: "$XXX",
    priceNote: "one-off, from",
    audience: "Smaller businesses that need a credible presence",
    description:
      "A tight, well-built site that makes a small business look established and gives customers a way to get in touch.",
    pages: "Up to 5 pages",
    timeline: "2–3 weeks",
    includes: [
      "Custom design — no templates",
      "Up to 5 pages",
      "Fully responsive build",
      "Contact form with spam protection",
      "SEO foundations — titles, descriptions, sitemap",
      "Google Business Profile guidance",
      "Deployment and domain connection",
      "30 days post-launch support",
    ],
    cta: "Start with Starter",
    highlighted: false,
  },
  {
    id: "growth",
    name: "Growth",
    price: "$XXX",
    priceNote: "one-off, from",
    audience: "Businesses that need the site to actively bring in work",
    description:
      "More pages, a proper enquiry or booking flow, and the content structure to rank for the services you actually sell.",
    pages: "Up to 12 pages",
    timeline: "4–6 weeks",
    includes: [
      "Everything in Starter",
      "Up to 12 pages",
      "Service pages built for search",
      "Multi-step quote or booking flow",
      "Copy structure and guidance",
      "Gallery or portfolio section",
      "Analytics and conversion tracking",
      "Accessibility pass to WCAG AA",
      "60 days post-launch support",
    ],
    cta: "Start with Growth",
    highlighted: true,
  },
  {
    id: "custom",
    name: "Custom",
    price: "Quoted",
    priceNote: "scoped per project",
    audience: "Businesses with requirements a package cannot cover",
    description:
      "Larger sites, online stores, integrations with systems you already run, or anything that needs to be designed from the problem up.",
    pages: "Unlimited",
    timeline: "Scoped per project",
    includes: [
      "Everything in Growth",
      "Unlimited pages",
      "E-commerce or bookings platform",
      "Third-party system integration",
      "Custom functionality",
      "Content migration",
      "Staged rollout",
      "Extended support window",
    ],
    cta: "Discuss a custom build",
    highlighted: false,
  },
];

export type AddOn = { name: string; price: string; note: string };

export const addOns: AddOn[] = [
  { name: "Website Maintenance", price: "$XX", note: "per month — updates, backups, monitoring and small content changes" },
  { name: "Hosting & domain management", price: "$XX", note: "per month — managed hosting, SSL and domain renewals handled" },
  { name: "Extra page", price: "$XXX", note: "per page — added to any package during the build" },
  { name: "Copywriting", price: "$XXX", note: "per page — written for your business and your search terms" },
];

export type Faq = { q: string; a: string };

export const pricingFaqs: Faq[] = [
  {
    q: "Why are the prices shown as placeholders?",
    a: "Because they have not been set in this build yet. Rather than publish a made-up figure, the packages are listed with their real inclusions and a placeholder price. Request a quote and you will get a fixed written figure for your actual scope.",
  },
  {
    q: "Is the price really fixed?",
    a: "Yes. Scope is agreed in writing before work starts and the price is fixed against it. If you ask for something outside that scope mid-project, you get a written variation to approve or decline before anything is built.",
  },
  {
    q: "Do I own the website?",
    a: "You do. The domain, the hosting account and the site itself are in your name. If you ever want to move on, everything comes with you.",
  },
  {
    q: "What do you need from me?",
    a: "Your logo if you have one, any photography you want used, and a sense of what your customers usually ask before they buy. If you do not have copy, there is guidance included and copywriting available as an add-on.",
  },
  {
    q: "How long does it take?",
    a: "Starter is typically two to three weeks and Growth four to six, from the point content is supplied. The usual cause of delay is waiting on content, so the process is structured to collect it early.",
  },
  {
    q: "Do you work with businesses outside Queensland?",
    a: "The focus is Queensland, but the work happens remotely either way, so location is not a barrier.",
  },
];

/** Set to false once the `price` fields above hold real figures. */
export const pricesArePlaceholder = true;
