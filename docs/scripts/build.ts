import { fileURLToPath } from 'node:url'
import { buildSite } from '#scripts/site'

// The directory the Pages workflow publishes as the site root.
await buildSite(fileURLToPath(new URL('../target/site', import.meta.url)))
