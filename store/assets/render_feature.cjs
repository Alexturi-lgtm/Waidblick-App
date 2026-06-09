// Render feature-graphic.html -> feature-graphic.png at exactly 1024x500.
// Uses the Playwright/Chromium installed under ~/.claude-browser.
const path = require('path');
const os = require('os');
const fs = require('fs');
const { chromium } = require(path.join(os.homedir(), '.claude-browser', 'node_modules', 'playwright'));

(async () => {
  const dir = __dirname;
  const htmlPath = 'file://' + path.join(dir, 'feature-graphic.html');
  const outPath = path.join(dir, 'feature-graphic.png');

  // Inline the icon as a data URI so it renders reliably under file://.
  const iconB64 = fs.readFileSync(path.join(dir, 'icon', 'play-icon-512.png')).toString('base64');
  const iconDataUri = 'data:image/png;base64,' + iconB64;

  const browser = await chromium.launch({ args: ['--no-sandbox', '--force-color-profile=srgb'] });
  const page = await browser.newPage({
    viewport: { width: 1024, height: 500 },
    deviceScaleFactor: 2, // render at 2x for crisp text, downscaled afterwards
  });
  await page.goto(htmlPath, { waitUntil: 'networkidle' });
  await page.evaluate((uri) => {
    const img = document.querySelector('.iconbox img');
    if (img) img.src = uri;
  }, iconDataUri);
  await page.waitForTimeout(400);
  // Screenshot the 1024x500 region (deviceScaleFactor=2 yields 2048x1000;
  // downscale_feature.py reduces it to exactly 1024x500 with LANCZOS supersampling).
  await page.screenshot({
    path: outPath,
    clip: { x: 0, y: 0, width: 1024, height: 500 },
  });
  await browser.close();
  console.log('rendered', outPath);
})().catch(e => { console.error(e); process.exit(1); });
