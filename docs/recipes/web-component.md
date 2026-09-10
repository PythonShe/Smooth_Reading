# Plain HTML and Web Components

Progressive enhancement over server-rendered HTML:

```html
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@smooth-reading/core/styles.css">
<article id="post">...</article>
<script type="module">
  import { applyToElement } from "https://cdn.jsdelivr.net/npm/@smooth-reading/core/+esm";
  const restore = applyToElement(document.getElementById("post"), { fixation: 3 });
  // restore() puts the original text nodes back.
</script>
```

Custom element:

```js
import { applyToElement } from "@smooth-reading/core";

class SmoothReadingElement extends HTMLElement {
  static observedAttributes = ["fixation", "saccade"];
  #restore;
  connectedCallback() { this.#apply(); }
  attributeChangedCallback() { if (this.isConnected) this.#apply(); }
  disconnectedCallback() { this.#restore?.(); }
  #apply() {
    this.#restore?.();
    this.#restore = applyToElement(this, {
      fixation: Number(this.getAttribute("fixation") ?? 3),
      saccade: Number(this.getAttribute("saccade") ?? 1),
    });
  }
}
customElements.define("smooth-reading", SmoothReadingElement);
```

```html
<smooth-reading fixation="4"><p>Wrap any markup.</p></smooth-reading>
```
