# Vue 3

```vue
<script setup lang="ts">
import { computed } from "vue";
import { tokenize, type SmoothOptions } from "@smooth-reading/core";
import "@smooth-reading/core/styles.css";

const props = withDefaults(defineProps<SmoothOptions & { text: string; tag?: string }>(), { tag: "span" });
const tokens = computed(() => tokenize(props.text, props));
</script>

<template>
  <component :is="tag">
    <template v-for="(t, i) in tokens" :key="i">
      <span v-if="t.type === 'word'">
        <span class="sr-fixation">{{ t.fixationText }}</span><span class="sr-rest">{{ t.restText }}</span>
      </span>
      <template v-else>{{ t.text }}</template>
    </template>
  </component>
</template>
```

Usage: `<SmoothText text="Smooth reading works." :fixation="3" tag="p" />`

Directive for existing DOM (client only):

```ts
import { applyToElement, type SmoothOptions } from "@smooth-reading/core";
import type { Directive } from "vue";

// One restore function per element, so several `v-smooth` elements never
// clobber each other's undo.
const restores = new WeakMap<HTMLElement, () => void>();

export const vSmooth: Directive<HTMLElement, SmoothOptions | undefined> = {
  mounted(el, { value }) { restores.set(el, applyToElement(el, value)); },
  updated(el, { value }) { restores.get(el)?.(); restores.set(el, applyToElement(el, value)); },
  unmounted(el) { restores.get(el)?.(); restores.delete(el); },
};
```
