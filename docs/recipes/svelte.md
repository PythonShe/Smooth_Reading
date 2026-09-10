# Svelte 5

`SmoothText.svelte`:

```svelte
<script lang="ts">
  import { tokenize, type SmoothOptions } from "@smooth-reading/core";
  import "@smooth-reading/core/styles.css";

  let { text, tag = "span", ...options }: SmoothOptions & { text: string; tag?: string } = $props();
  const tokens = $derived(tokenize(text, options));
</script>

<svelte:element this={tag}>
  {#each tokens as t}
    {#if t.type === "word"}<span><span class="sr-fixation">{t.fixationText}</span><span class="sr-rest">{t.restText}</span></span>{:else}{t.text}{/if}
  {/each}
</svelte:element>
```

Action for existing DOM:

```ts
import { applyToElement, type SmoothOptions } from "@smooth-reading/core";
import type { Action } from "svelte/action";

export const smooth: Action<HTMLElement, SmoothOptions | undefined> = (node, options) => {
  let restore = applyToElement(node, options);
  return {
    update(next) { restore(); restore = applyToElement(node, next); },
    destroy() { restore(); },
  };
};
```

Usage: `<p use:smooth={{ fixation: 3 }}>Smooth reading works.</p>`
