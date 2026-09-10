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

The component above is a pure function of its props: `tokenize` is linear and fast, so there is no `useMemo` or `useEffect` in the common path, and it renders identically on the server and in React Server Components.

Large texts: if a very long article re-renders often for unrelated reasons, memoise the component itself rather than reaching for effects:

```tsx
export const SmoothText = memo(function SmoothText({ children, ...options }: Props) { /* as above */ });
```

Applying to existing rendered HTML (a CMS article you receive as a string) is the one case that needs DOM access. Use a **ref callback**, not `useEffect`: React calls it once when the node mounts and once with `null` when it unmounts, which is exactly the apply/restore lifecycle, and it never re-runs on unrelated renders.

```tsx
"use client";
import { useCallback, useRef } from "react";
import { applyToElement } from "@smooth-reading/core";

export function SmoothArticle({ html }: { html: string }) {
  const restore = useRef<() => void>();
  const attach = useCallback((node: HTMLDivElement | null) => {
    restore.current?.();
    restore.current = node ? applyToElement(node, { fixation: 3 }) : undefined;
  }, []);
  return <div ref={attach} dangerouslySetInnerHTML={{ __html: html }} />; // html is your own trusted markup
}
```

Prefer the pure component whenever you control the text; keep `applyToElement` for markup you do not own.
