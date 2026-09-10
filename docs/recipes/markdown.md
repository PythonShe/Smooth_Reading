# Markdown and static-site pipelines

`toHtml()` is a pure string transform, so it slots into any HTML post-processing step. Existing tags and entities are passed through, and text inside `code`, `pre`, `kbd`, `samp`, `script`, `style` and `textarea` is left alone.

Post-process rendered HTML (any generator):

```ts
import { toHtml } from "@smooth-reading/core";
const enhanced = toHtml(renderedHtml, { fixation: 3, tag: "span", className: "sr-fixation" });
```

rehype plugin (Astro, Next MDX, Docusaurus):

```ts
import { visit } from "unist-util-visit";
import { tokenize } from "@smooth-reading/core";

export function rehypeSmoothReading(options = {}) {
  return (tree) => {
    visit(tree, "text", (node, index, parent) => {
      if (!parent || ["code", "pre", "script", "style"].includes(parent.tagName)) return;
      const children = tokenize(node.value, options).map((t) =>
        t.type === "word"
          ? { type: "element", tagName: "span", properties: {}, children: [
              { type: "element", tagName: "b", properties: {}, children: [{ type: "text", value: t.fixationText }] },
              { type: "text", value: t.restText },
            ] }
          : { type: "text", value: t.text },
      );
      parent.children.splice(index, 1, ...children);
      return index + children.length;
    });
  };
}
```

Emit Markdown instead of HTML (for chat apps or note tools):

```ts
import { tokenize } from "@smooth-reading/core";
const md = tokenize(text).map((t) => (t.type === "word" && t.fixation > 0 ? `**${t.fixationText}**${t.restText}` : t.text)).join("");
```

The Python CLI does the same with `smooth-reading --markdown`.
