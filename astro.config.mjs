import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://nulcell.com',
  integrations: [sitemap()],
  redirects: { '/confidential': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' },
});
