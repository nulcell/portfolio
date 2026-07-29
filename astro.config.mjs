import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://portfolio.nulcell.com',
  integrations: [sitemap()],
  trailingSlash: 'ignore',
  build: {
    format: 'directory',
  },
});
