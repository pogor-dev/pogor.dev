
import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';
import eslintPluginAstro from 'eslint-plugin-astro';
import pluginJsxA11y from "eslint-plugin-jsx-a11y";


export default tseslint.config(
  eslint.configs.recommended,
  ...tseslint.configs.strict,
  ...tseslint.configs.stylistic,
  ...eslintPluginAstro.configs.recommended,
  {
    ignores: ["**/*.astro"],
    plugins: {
      'jsx-a11y': pluginJsxA11y,
    },
    rules: pluginJsxA11y.configs.recommended.rules,
  },
  {
    ignores: [".husky", ".vscode", "node_modules", "public", "dist", ".yarn"]
  },
  {
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      parserOptions: {
        node: true,
        es2022: true,
        browser: true,
      }
    },
  }
)