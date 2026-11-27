// Web smoke test: serve an exported build, load it in headless Chromium
// (Playwright, pinned in package-lock.json), and pass only if the canvas
// appears, the game prints its boot marker (the Events bus round trip ran in
// the browser), and there are no console errors, page errors or failed requests,
// and no audio warning (audio started before the first user gesture, #26).
//
// Usage: node tests/e2e/web-smoke.mjs <export-dir>
import { chromium } from "playwright";
import { serveStatic } from "../../scripts/serve-static.mjs";

const BOOT_MARKER = "mechapilot: boot ok";
const BOOT_TIMEOUT_MS = Number(process.env.E2E_BOOT_TIMEOUT_MS ?? "90000");
const SETTLE_MS = 2_000;
// Chromium's notices for audio started before a user gesture (autoplay policy),
// at any console level: Chromium logs some of them as log or info, not warning.
const AUDIO_WARNING = /AudioContext|autoplay|user gesture/i;

const dir = process.argv[2];
if (!dir) {
  console.error("usage: web-smoke.mjs <export-dir>");
  process.exit(64);
}

const problems = [];
// Serve with the production Game Site's Content-Security-Policy (scripts/e2e-web
// reads it from infra/), so a CSP that would block the game fails here first.
const csp = process.env.E2E_CSP ?? "";
const { server, url } = await serveStatic(dir, 0, csp ? { "Content-Security-Policy": csp } : {});
if (csp) console.log(`web-smoke: serving with CSP: ${csp}`);
// WebGL 2 without a GPU: Chromium's software renderer (SwiftShader via ANGLE).
const browser = await chromium.launch({
  headless: true,
  args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
});
let booted = false;
try {
  const page = await browser.newPage();
  page.on("console", (msg) => {
    const text = msg.text();
    console.log(`[console.${msg.type()}] ${text}`);
    if (msg.type() === "error") problems.push(`console error: ${text}`);
    if (AUDIO_WARNING.test(text)) problems.push(`audio warning (console.${msg.type()}): ${text}`);
  });
  page.on("pageerror", (err) => problems.push(`page error: ${err.message}`));
  await page.exposeFunction("__reportCspViolation", (v) => problems.push(`CSP violation: ${v}`));
  await page.addInitScript(() => {
    document.addEventListener("securitypolicyviolation", (e) => {
      window.__reportCspViolation(`${e.violatedDirective} blocked ${e.blockedURI || "inline"}`);
    });
  });
  page.on("requestfailed", (req) => problems.push(`request failed: ${req.url()} ${req.failure()?.errorText ?? ""}`));
  page.on("response", (res) => {
    if (res.status() >= 400) problems.push(`HTTP ${res.status()}: ${res.url()}`);
  });

  const marker = page.waitForEvent("console", {
    predicate: (msg) => msg.text().includes(BOOT_MARKER),
    timeout: BOOT_TIMEOUT_MS,
  });
  await page.goto(`${url}index.html`, { waitUntil: "load" });
  await marker.then(() => (booted = true)).catch(() => problems.push(`no "${BOOT_MARKER}" within ${BOOT_TIMEOUT_MS} ms`));

  const canvas = await page.locator("#canvas").boundingBox().catch(() => null);
  if (!canvas || canvas.width < 1 || canvas.height < 1) problems.push("the game canvas is missing or has no size");
  await page.waitForTimeout(SETTLE_MS);
} finally {
  await browser.close();
  server.close();
}

if (problems.length > 0 || !booted) {
  for (const p of problems) console.error(`FAIL ${p}`);
  process.exit(1);
}
console.log("web-smoke: the exported page booted with no console errors");
