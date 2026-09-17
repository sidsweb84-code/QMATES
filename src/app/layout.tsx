import type { Metadata, Viewport } from "next";
import { Bricolage_Grotesque, DM_Sans, Instrument_Serif } from "next/font/google";
import { MotionProvider } from "@/components/layout/MotionProvider";
import { Navbar } from "@/components/layout/Navbar";
import { DockNav } from "@/components/layout/DockNav";
import { Footer } from "@/components/layout/Footer";
import { PageTransition } from "@/components/layout/PageTransition";
import { site } from "@/data/site";
import "./globals.css";

/* Self-hosted by next/font: no render-blocking request, no layout shift. */
const bricolage = Bricolage_Grotesque({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-bricolage",
});

const dmSans = DM_Sans({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-dm-sans",
});

const instrument = Instrument_Serif({
  subsets: ["latin"],
  weight: "400",
  style: ["normal", "italic"],
  display: "swap",
  variable: "--font-instrument",
});

export const metadata: Metadata = {
  metadataBase: new URL(site.url),
  title: {
    default: `${site.name} — ${site.tagline}`,
    template: `%s — ${site.name}`,
  },
  description: site.description,
  applicationName: site.name,
  authors: [{ name: site.name }],
  keywords: [
    "web design Queensland",
    "Brisbane web designer",
    "small business websites",
    "website development QLD",
    "website redesign Queensland",
  ],
  openGraph: {
    type: "website",
    locale: "en_AU",
    siteName: site.name,
    title: `${site.name} — ${site.tagline}`,
    description: site.description,
    url: site.url,
  },
  twitter: {
    card: "summary_large_image",
    title: `${site.name} — ${site.tagline}`,
    description: site.description,
  },
  robots: { index: true, follow: true },
  alternates: { canonical: "/" },
};

export const viewport: Viewport = {
  themeColor: "#06090a",
  width: "device-width",
  initialScale: 1,
  /* Zoom is deliberately left enabled. */
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html
      lang="en-AU"
      className={`${bricolage.variable} ${dmSans.variable} ${instrument.variable}`}
    >
      <body>
        <MotionProvider>
          <Navbar />
          <main id="main" tabIndex={-1}>
            <PageTransition>{children}</PageTransition>
          </main>
          <Footer />
          <DockNav />
        </MotionProvider>
      </body>
    </html>
  );
}
