# React

Works in React 18/19, Next.js App Router (server and client components), Remix and Astro islands. No hooks are needed for the static case.

```tsx
import { tokenize, type SmoothOptions } from "@smooth-reading/core";
import "@smooth-reading/core/styles.css";

type Props = SmoothOptions & { children: string; as?: keyof React.JSX.IntrinsicElements };

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

## Content you fetch (CMS, API, Markdown pipeline)

Do the transform in the data layer, not in the DOM. `toHtml` is a pure string function, so it belongs in the query's `select` (TanStack Query), a route loader (Remix, React Router), or a server component. The component then renders already-emphasised HTML once, with nothing to synchronise afterwards.

TanStack Query:

```tsx
import { useQuery } from "@tanstack/react-query";
import { toHtml } from "@smooth-reading/core";

const smoothOptions = { fixation: 3, tag: "span", className: "sr-fixation" } as const;

export function Article({ id }: { id: string }) {
  const { data } = useQuery({
    queryKey: ["article", id],
    queryFn: () => fetch(`/api/articles/${id}`).then((r) => r.text()),
    select: (html) => toHtml(html, smoothOptions), // memoised by Query; re-runs only when data changes
  });
  if (!data) return null;
  return <div dangerouslySetInnerHTML={{ __html: data }} />; // your own trusted markup
}
```

Server component or loader (Next.js App Router, Remix, React Router):

```tsx
import { toHtml } from "@smooth-reading/core";

export default async function ArticlePage({ params }: { params: { id: string } }) {
  const html = await getArticleHtml(params.id);
  return <div dangerouslySetInnerHTML={{ __html: toHtml(html, { fixation: 3 }) }} />;
}
```

Let users change the strength: keep `fixation` in state or the URL and include it in the query key or `select`; Query recomputes the derived HTML, and nothing touches the DOM directly.

```tsx
const [fixation, setFixation] = useState<1 | 2 | 3 | 4 | 5>(3);
const { data } = useQuery({
  queryKey: ["article", id],
  queryFn: fetchArticle,
  select: useCallback((html: string) => toHtml(html, { fixation }), [fixation]),
});
```

## Last resort: markup you do not own

If the HTML is already in the DOM and you cannot run it through `toHtml` first (a third-party widget, a portal you do not control), use `applyToElement` with a **ref callback**. React calls it once when the node mounts and once with `null` on unmount, which matches the apply/restore lifecycle without an effect.

```tsx
"use client";
import { useCallback, useRef } from "react";
import { applyToElement } from "@smooth-reading/core";

export function SmoothWidget({ children }: { children: React.ReactNode }) {
  const restore = useRef<(() => void) | undefined>(undefined);
  const attach = useCallback((node: HTMLDivElement | null) => {
    restore.current?.();
    restore.current = node ? applyToElement(node, { fixation: 3 }) : undefined;
  }, []);
  return <div ref={attach}>{children}</div>;
}
```

Order of preference: pure `SmoothText` when you own the text, `toHtml` in the data layer when you fetch HTML, `applyToElement` via ref callback only for DOM you do not own.
