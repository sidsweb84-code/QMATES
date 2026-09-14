import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  devIndicators: false,

  /* Static export. Forms post straight to Web3Forms from the browser, so the
     site needs no server of its own and can be uploaded as plain files to
     GoDaddy (or any static host). `npm run build` writes them to /out. */
  output: "export",
  /* Emits /portfolio/index.html rather than /portfolio.html, which is what
     Apache serves correctly for a clean /portfolio URL. */
  trailingSlash: true,
  /* The Image Optimisation API needs a server; static export has none. */
  images: { unoptimized: true },
};

export default nextConfig;
