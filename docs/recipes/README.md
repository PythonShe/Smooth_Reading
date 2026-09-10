# Framework recipes

Framework adapters are intentionally not published as separate packages. Instead, this directory provides lightweight, copy-paste recipes built directly on `@smooth-reading/core`'s `tokenize()`.

## Core design principles

- **Render native elements, avoid `innerHTML`**: Recipes build native virtual DOM nodes or template elements directly from the `tokenize()` stream. This guarantees complete XSS safety, proper component lifecycle management, and seamless server-side rendering (SSR/RSC).
- **Derive, do not synchronize**: Tokenization is linear and fast. Derive tokens as a pure function of component props/inputs without reaching for redundant `useEffect` or state synchronization.
- **Data layer transformation for external HTML**: When rendering pre-existing HTML (e.g. from a CMS, Markdown pipeline, or API), transform the HTML string in your data layer (e.g. a TanStack Query `select`, route loader, or server component) using `toHtml()`.

---

## Available recipes

| Framework / Environment | File | Supported Versions | Highlights |
| --- | --- | --- | --- |
| **React / Next.js / Remix** | [react.md](react.md) | React 18, 19, RSC, Remix | Pure function component, TanStack Query integration, and ref callback lifecycle. |
| **React Native / Expo** | [react-native.md](react-native.md) | React Native 0.72+, Expo SDK 50+ | Nested `<Text>` rendering with Hermes engine compatibility. |
| **Vue 3** | [vue.md](vue.md) | Vue 3.3+ | `<script setup>` with computed tokens, plus a `v-smooth` directive for live DOM. |
| **Svelte 5** | [svelte.md](svelte.md) | Svelte 5 (Runes) | Runes-based component (`$props`, `$derived`) and `use:smooth` action. |
| **Angular** | [angular.md](angular.md) | Angular 17+ | Signals-based standalone component and directive. |
| **Web Components / HTML** | [web-component.md](web-component.md) | Standard Web APIs | Custom element (`<smooth-reading>`) and progressive enhancement script. |
| **Markdown Pipelines** | [markdown.md](markdown.md) | Unified / Rehype (Astro, Docusaurus) | Rehype AST visitor plugin and pure Markdown emphasis generators. |

---

## Publishing community packages

If you build and publish a dedicated package from one of these recipes, you are welcome to do so under the terms of the Apache-2.0 license. Please provide a distinct package name and credit/link back to the upstream Smooth Reading repository.
