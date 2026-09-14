import Link from "next/link";
import { cn } from "@/lib/cn";
import type { Testimonial } from "@/data/testimonials";
import { getProject } from "@/data/projects";
import { Star } from "@/components/ui/Icon";

function Rating({ value }: { value: number }) {
  return (
    <div className="flex items-center gap-1" role="img" aria-label={`Rated ${value} out of 5`}>
      {[1, 2, 3, 4, 5].map((n) => (
        <Star key={n} size={14} filled={n <= value} className="text-sand" />
      ))}
    </div>
  );
}

/** Shown in place of an attribution while a slot has no real client quote. */
export function AwaitingQuote() {
  return (
    <p className="eyebrow inline-flex items-center gap-1.5 text-sand">
      <span aria-hidden="true" className="size-1 rounded-full bg-sand" />
      Awaiting client quote
    </p>
  );
}

export function TestimonialCard({
  testimonial,
  className,
}: {
  testimonial: Testimonial;
  className?: string;
}) {
  const project = testimonial.projectSlug ? getProject(testimonial.projectSlug) : undefined;

  return (
    <figure
      className={cn(
        "group/t flex h-full flex-col rounded-[var(--radius-lg)] border border-line bg-surface p-6",
        "transition-[border-color,transform] duration-[var(--duration-slow)] ease-[var(--ease-out-expo)]",
        "hover:-translate-y-1 hover:border-line-strong md:p-7",
        className,
      )}
    >
      {testimonial.rating ? <Rating value={testimonial.rating} /> : null}

      <blockquote className="mt-4 flex-1">
        <p
          className={cn(
            "text-[1.0625rem] leading-relaxed",
            testimonial.isPlaceholder ? "text-dim italic" : "text-bone",
          )}
        >
          {testimonial.isPlaceholder ? testimonial.quote : `“${testimonial.quote}”`}
        </p>
      </blockquote>

      <figcaption className="rule-t mt-6 pt-5">
        {testimonial.isPlaceholder ? (
          <AwaitingQuote />
        ) : (
          <>
            <p className="font-display font-semibold text-bone">{testimonial.author}</p>
            <p className="mt-1 text-meta text-mist">
              {testimonial.role}
              {testimonial.role && testimonial.business ? ", " : ""}
              {testimonial.business}
            </p>
          </>
        )}
        <div className="mt-3 flex flex-wrap items-center gap-x-3 gap-y-2">
          <span className="eyebrow text-dim">{testimonial.businessType}</span>
          {project ? (
            <Link
              href={`/portfolio/${project.slug}`}
              className="inline-flex min-h-6 items-center py-0.5 text-[0.75rem] text-mist underline decoration-line-strong underline-offset-4 transition-colors duration-[var(--duration-base)] hover:text-reef hover:decoration-reef"
            >
              {project.name} case study
            </Link>
          ) : null}
        </div>
      </figcaption>
    </figure>
  );
}
