// Web smoke test: serve an exported build, load it in headless Chromium
// (Playwright, pinned in package-lock.json), and pass only if the canvas
// appears, the game prints its boot marker (the Events bus round trip ran in
// the browser), a player can start a Run from the Boot and Title screens and
// fly Level 1 (the game prints its play marker when the Skirmish begins; the
// smoke then flies and fires for a while, and the game must report that the
// player fired and that the mech flew under the move input), and there are no
// console errors, page errors or failed requests at any point, and no audio
// warning (audio started before the first user gesture, #26).
//
// Usage: node tests/e2e/web-smoke.mjs <export-dir>
import { chromium } from "playwright";
import { serveStatic } from "../../scripts/serve-static.mjs";

const BOOT_MARKER = "mechapilot: boot ok";
const PLAY_MARKER = "mechapilot: level 1 in play";
// Printed once each by godot/game/run/play_markers.gd during the flight below.
const FLIGHT_MARKERS = ["mechapilot: player fired", "mechapilot: player steered"];
const BOOT_TIMEOUT_MS = Number(process.env.E2E_BOOT_TIMEOUT_MS ?? "90000");
const SETTLE_MS = 2_000;
// Chromium's notices for audio started before a user gesture (autoplay policy),
// at any console level: Chromium logs some of them as log or info, not warning.
const AUDIO_WARNING = /AudioContext|autoplay|user gesture/i;
const PLAY_TIMEOUT_MS = Number(process.env.E2E_PLAY_TIMEOUT_MS ?? "30000");
// Menus: a human pause between presses. Flight: keys held this long, in turn.
const MENU_PAUSE_MS = 800;
const FLIGHT_HOLD_MS = 1_500;
const FLIGHT_KEYS = [
  ["KeyD", "ArrowRight"],
  ["KeyW", "ArrowUp"],
  ["KeyA", "ArrowLeft"],
  ["KeyS", "Space"],
];

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
let played = false;
const seen = new Set();
try {
  const page = await browser.newPage();
  page.on("console", (msg) => {
    const text = msg.text();
    seen.add(text);
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
  if (booted && canvas) {
    // Boot: tap the canvas (the audio-unlocking gesture). Title: Enter on Play.
    const playing = page.waitForEvent("console", {
      predicate: (msg) => msg.text().includes(PLAY_MARKER),
      timeout: PLAY_TIMEOUT_MS,
    });
    await page.mouse.click(canvas.x + canvas.width / 2, canvas.y + canvas.height / 2);
    await page.waitForTimeout(MENU_PAUSE_MS);
    await page.keyboard.press("Enter");
    await playing.then(() => (played = true)).catch(() => problems.push(`no "${PLAY_MARKER}" within ${PLAY_TIMEOUT_MS} ms`));
    for (const keys of played ? FLIGHT_KEYS : []) {
      for (const key of keys) await page.keyboard.down(key);
      await page.waitForTimeout(FLIGHT_HOLD_MS);
      for (const key of keys) await page.keyboard.up(key);
    }
    if (played) {
      for (const marker of FLIGHT_MARKERS) {
        if (!seen.has(marker)) problems.push(`no "${marker}" while flying Level 1`);
      }
    }
  }
  await page.waitForTimeout(SETTLE_MS);
} finally {
  await browser.close();
  server.close();
}

if (problems.length > 0 || !booted || !played) {
  for (const p of problems) console.error(`FAIL ${p}`);
  process.exit(1);
}
console.log("web-smoke: the exported page booted and played Level 1 with no console errors");
