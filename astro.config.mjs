// @ts-check
import { defineConfig, fontProviders, memoryCache } from "astro/config";
import solidJs from "@astrojs/solid-js";
import tailwindcss from "@tailwindcss/vite";

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
  integrations: [solidJs()],
  vite: {
    plugins: [tailwindcss()],
  },
  experimental: {
    rustCompiler: false,
    queuedRendering: {
      enabled: true,
    },
    cache: { provider: memoryCache() },
  },
});
