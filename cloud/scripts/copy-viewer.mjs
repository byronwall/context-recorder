// Copies the shared viewer (../scripts/viewer.html) into the Worker's static assets so GET /s/:id/
// serves the same file the Mac app embeds. The copy is gitignored; scripts/viewer.html is the source.
import { copyFileSync, existsSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const src = resolve(here, "../../scripts/viewer.html");
const dest = resolve(here, "../public/viewer.html");
if (!existsSync(src)) {
  console.error(`copy-viewer: ${src} not found`);
  process.exit(1);
}
mkdirSync(dirname(dest), { recursive: true });
copyFileSync(src, dest);
console.log(`copy-viewer: ${src} -> ${dest}`);
