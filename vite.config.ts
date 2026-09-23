import type { UserConfig } from 'vite';

// Keep the game's origin stable and separate from the existing dashboard.
// These defaults also apply when running node_modules/.bin/vite.cmd directly.
export default {
  base: process.env.GITHUB_PAGES ? '/Seoul-Hero/' : '/',
  server: { host: '127.0.0.1', port: 5174, strictPort: true },
  preview: { host: '127.0.0.1', port: 4174, strictPort: true },
} satisfies UserConfig;
