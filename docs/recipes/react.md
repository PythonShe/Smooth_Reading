# React

Works in React 18/19, Next.js App Router (server and client components), Remix and Astro islands. No hooks are needed for the static case.

```tsx
import { tokenize, type SmoothOptions } from "@smooth-reading/core";
import "@smooth-reading/core/styles.css";

type Props = SmoothOptions & { children: string; as?: keyof JSX.IntrinsicElements };

export function SmoothText({ children, as: Tag = "span", ...options }: Props) {
  const tokens = tokenize(children, options);
  return (
    <Tag>
      {tokens.map((t, i) =>
        t.type === "word" ? (
          <span key={i}>
            <span className="sr-fixation">{t.fixationText}</span>
            <span className="sr-rest">{t.restText}</span>
          </span>
        ) : (
          t.text
        ),
      )}
    </Tag>
  );
}
```

Usage:

```tsx
<SmoothText fixation={3} saccade={1} as="p">
  Smooth reading works in any framework.
</SmoothText>
```

Memoise for large texts:

```tsx
const tokens = useMemo(() => tokenize(text, options), [text, options.fixation, options.saccade]);
```

Applying to existing rendered HTML (client only, e.g. a CMS article):

```tsx
"use client";
import { useEffect, useRef } from "react";
import { applyToElement } from "@smooth-reading/core";

export function SmoothArticle({ html }: { html: string }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => ref.current ? applyToElement(ref.current, { fixation: 3 }) : undefined, [html]);
  return <div ref={ref} dangerouslySetInnerHTML={{ __html: html }} />; // html is your own trusted markup
}
```
