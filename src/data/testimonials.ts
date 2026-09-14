/* ============================================================================
 * TESTIMONIALS
 * ----------------------------------------------------------------------------
 * IMPORTANT — READ BEFORE EDITING.
 *
 * No real person has endorsed QMATES yet, so no real name appears here.
 * Every entry is `isPlaceholder: true` and the UI labels it as awaiting a
 * real quote. The quote text describes the KIND of outcome the work aims at;
 * it is not attributed to anyone and is never presented as a real review.
 *
 * TO ADD A REAL TESTIMONIAL:
 *   1. Set `isPlaceholder: false`.
 *   2. Put the client's real words in `quote` — do not paraphrase them.
 *   3. Fill `author`, `role`, `business`.
 *   4. Only set `rating` if the client actually gave one.
 *   5. Link it to a case study with `projectSlug` if relevant.
 *
 * Any entry left as a placeholder renders with a visible "Awaiting client
 * quote" marker, so unreplaced content can never read as a real endorsement.
 * ========================================================================== */

export type Testimonial = {
  id: string;
  quote: string;
  author: string | null;
  role: string | null;
  business: string | null;
  businessType: string;
  projectSlug: string | null;
  rating: number | null;
  isPlaceholder: boolean;
  featured: boolean;
};

export const testimonials: Testimonial[] = [
  {
    id: "t1",
    quote:
      "Placeholder — reserved for a client quote about the enquiry process. The intent of this slot is a client describing how the new site changed the quality of the leads arriving, not just the quantity.",
    author: null,
    role: null,
    business: null,
    businessType: "Trades — solar",
    projectSlug: "coastline-solar",
    rating: null,
    isPlaceholder: true,
    featured: true,
  },
  {
    id: "t2",
    quote:
      "Placeholder — reserved for a client quote about the build process. This slot is intended for a client describing what it was like to work with QMATES: communication, timelines and how decisions were made.",
    author: null,
    role: null,
    business: null,
    businessType: "Trades — mobile mechanic",
    projectSlug: "driveway-mechanical",
    rating: null,
    isPlaceholder: true,
    featured: false,
  },
  {
    id: "t3",
    quote:
      "Placeholder — reserved for a client quote about self-management. Intended for a client describing how easily they can update their own menu, pricing or hours without needing a developer.",
    author: null,
    role: null,
    business: null,
    businessType: "Hospitality",
    projectSlug: "north-quay-kitchen",
    rating: null,
    isPlaceholder: true,
    featured: false,
  },
  {
    id: "t4",
    quote:
      "Placeholder — reserved for a client quote about accessibility. Intended for a practice describing how their older patients found the new booking flow compared with phoning reception.",
    author: null,
    role: null,
    business: null,
    businessType: "Health — physiotherapy",
    projectSlug: "hinterland-physio",
    rating: null,
    isPlaceholder: true,
    featured: false,
  },
  {
    id: "t5",
    quote:
      "Placeholder — reserved for a client quote about mobile performance. Intended for a client describing how the site behaves for customers on patchy regional connections.",
    author: null,
    role: null,
    business: null,
    businessType: "Retail — regional produce",
    projectSlug: "granite-belt-provisions",
    rating: null,
    isPlaceholder: true,
    featured: false,
  },
  {
    id: "t6",
    quote:
      "Placeholder — reserved for a client quote about tone and credibility. Intended for a professional practice describing how the site changed the first impression clients form before making contact.",
    author: null,
    role: null,
    business: null,
    businessType: "Professional services — legal",
    projectSlug: "moreton-legal",
    rating: null,
    isPlaceholder: true,
    featured: false,
  },
];

export const featuredTestimonial = testimonials.find((t) => t.featured) ?? testimonials[0];
export const hasRealTestimonials = testimonials.some((t) => !t.isPlaceholder);
