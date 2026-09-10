# React Native / Expo

`@smooth-reading/core` has no DOM dependency, so `tokenize()` runs in Hermes. `Intl.Segmenter` is available in Hermes on recent React Native versions; otherwise the regex fallback is used automatically.

```tsx
import { Text, type TextProps } from "react-native";
import { tokenize, type SmoothOptions } from "@smooth-reading/core";

type Props = SmoothOptions & TextProps & { children: string };

export function SmoothText({ children, fixation, saccade, minWordLength, emphasizeNumbers, locale, ...textProps }: Props) {
  const tokens = tokenize(children, { fixation, saccade, minWordLength, emphasizeNumbers, locale });
  return (
    <Text {...textProps}>
      {tokens.map((t, i) =>
        t.type === "word" ? (
          <Text key={i}>
            <Text style={{ fontWeight: "700" }}>{t.fixationText}</Text>
            <Text style={{ opacity: 0.85 }}>{t.restText}</Text>
          </Text>
        ) : (
          t.text
        ),
      )}
    </Text>
  );
}
```
