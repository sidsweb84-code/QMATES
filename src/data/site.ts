/* ============================================================================
 * SITE CONFIGURATION
 * ----------------------------------------------------------------------------
 * REPLACE THE PLACEHOLDER VALUES BELOW WITH REAL QMATES DETAILS.
 * Every placeholder is marked with a  // TODO:  comment.
 * Nothing else in the codebase hardcodes contact details.
 * ========================================================================== */

export const site = {
  name: "QMATES",
  tagline: "Queensland's Online Business Partner",
  description:
    "QMATES designs and builds professional websites for Queensland businesses — clear, fast and built to turn visitors into enquiries.",

  // TODO: replace with your real production domain before launch.
  url: "https://qmates.com.au",

  /* NOTE: the address supplied was "sidsweb84@gmail.com.au". There is no
     gmail.com.au mail domain, so mail to it bounces — corrected to the
     near-certain intent. Change it back if the original was deliberate. */
  email: "sidsweb84@gmail.com",
  phone: "0472 747 757",
  phoneHref: "tel:+61472747757",

  /* Web3Forms access key. This is a PUBLIC key by design — Web3Forms expects
     it in client-side markup, and it carries no account access. Submissions
     are delivered to the address registered against it at web3forms.com.
     Spam protection is the hidden `botcheck` honeypot on both forms. */
  web3formsKey: "c9c4d3b3-6c1d-4c30-9d83-d4a57d83a283",

  location: "Brisbane, Queensland",
  serviceArea: "Working with businesses across South East Queensland and regional QLD.",

  // TODO: add real profile URLs, or delete the entries you do not use.
  // Entries with a `null` href are rendered as plain text, not broken links.
  socials: [
    { label: "Instagram", handle: "@qmates", href: null as string | null },
    { label: "Facebook", handle: "QMATES", href: null as string | null },
    { label: "LinkedIn", handle: "QMATES", href: null as string | null },
  ],

  // TODO: add your ABN if you want it displayed in the footer, or leave null.
  abn: null as string | null,

  availability: "Taking on new projects",
} as const;

export type NavItem = { label: string; href: string };

export const navItems: NavItem[] = [
  { label: "Home", href: "/" },
  { label: "Portfolio", href: "/portfolio" },
  { label: "Gallery", href: "/gallery" },
  { label: "Testimonials", href: "/testimonials" },
  { label: "Pricing", href: "/pricing" },
  { label: "About", href: "/about" },
  { label: "Contact", href: "/contact" },
];
