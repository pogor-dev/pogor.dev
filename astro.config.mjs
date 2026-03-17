// @ts-check
import { defineConfig, fontProviders, memoryCache } from "astro/config";

// https://astro.build/config
export default defineConfig({
  security: { csp: true },
  markdown: { syntaxHighlight: "shiki", shikiConfig: { theme: "css-variables" } },
  fonts: [
    {
      name: "Inter",
      cssVariable: "--font-inter",
      provider: fontProviders.fontsource(),
    },
    {
      name: "Montserrat",
      cssVariable: "--font-montserrat",
      provider: fontProviders.fontsource(),
    },
  ],
  experimental: {
    rustCompiler: true,
    queuedRendering: {
      enabled: true,
    },
    cache: { provider: memoryCache() },
  },
});
