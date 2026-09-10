import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // Per-file overrides use a `@vitest-environment` docblock (see test/dom.test.ts).
    environment: 'node',
    include: ['test/**/*.test.ts'],
  },
});
