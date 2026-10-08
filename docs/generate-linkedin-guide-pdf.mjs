/**
 * Generate docs/LINKEDIN_AD_SYNC_USER_GUIDE_EN.pdf from HTML.
 * Run from repo root: node docs/generate-linkedin-guide-pdf.mjs
 * Requires puppeteer in docs/node_modules OR run from temp install (see README in docs).
 */
import { readFileSync, existsSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const htmlPath = join(__dirname, 'LINKEDIN_AD_SYNC_USER_GUIDE_EN.html');
const pdfPath = join(__dirname, 'LINKEDIN_AD_SYNC_USER_GUIDE_EN.pdf');

const html = readFileSync(htmlPath, 'utf8');

let puppeteer;
const localPuppeteer = join(__dirname, 'node_modules', 'puppeteer');
try {
  if (existsSync(localPuppeteer)) {
    puppeteer = (await import(join(localPuppeteer, 'index.js'))).default;
  } else {
    puppeteer = (await import('puppeteer')).default;
  }
} catch {
  console.error('Install puppeteer: npm install puppeteer --prefix docs');
  process.exit(1);
}

const browser = await puppeteer.launch({ headless: 'new', args: ['--no-sandbox'] });
const page = await browser.newPage();
await page.setContent(html, { waitUntil: 'networkidle0', timeout: 180000 });
await page.waitForFunction(
  () => {
    const blocks = document.querySelectorAll('.mermaid');
    if (blocks.length === 0) return true;
    return [...blocks].every((el) => el.querySelector('svg'));
  },
  { timeout: 120000 }
);
await page.pdf({
  path: pdfPath,
  format: 'A4',
  printBackground: true,
  margin: { top: '16mm', right: '14mm', bottom: '16mm', left: '14mm' }
});
await browser.close();
console.log('PDF written:', pdfPath);
