import type { GiscusProps } from "@giscus/react";

export const GISCUS: GiscusProps = {
  repo: "pogor-dev/pogor.dev",
  repoId: "R_kgDOLxGKaQ",
  category: "💬 Blog comments",
  categoryId: "DIC_kwDOLxGKac4CoZ5Z",
  mapping: "pathname",
  reactionsEnabled: "1",
  emitMetadata: "0",
  inputPosition: "bottom",
  lang: "en",
  loading: "lazy",
} as const;
