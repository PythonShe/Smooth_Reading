# Recipes

Framework wrappers are intentionally not published as packages. Each recipe below is a complete, copy-paste component built on `@smooth-reading/core`'s `tokenize()`. They render real elements (no `innerHTML`, except where you already own fetched HTML and transform it with `toHtml` in the data layer), so they are safe with untrusted text and work with server-side rendering.

| Recipe | File |
| --- | --- |
| React / Next.js / Remix | [react.md](react.md) |
| React Native | [react-native.md](react-native.md) |
| Vue 3 | [vue.md](vue.md) |
| Svelte 5 | [svelte.md](svelte.md) |
| Angular | [angular.md](angular.md) |
| Plain HTML / Web Component | [web-component.md](web-component.md) |
| Markdown / static site pipelines | [markdown.md](markdown.md) |

If you publish a wrapper package built from one of these, please give it your own name and a link back to this repository.
