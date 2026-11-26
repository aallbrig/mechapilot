// Let the browser decide (#30): load every document of a built site in the
// pinned Chrome for Testing and fail on anything that is not a static,
// self-contained page.
//
// Usage: node scripts/site-observe.mjs <chrome-path> <site-root>...
//
// Exit status (fail closed):
//   0  every document was fully observed (load fired, then the whole
//      observation window passed) and none had a finding
//   1  at least one document had a finding (and every document was observed)
//   2  the check could not observe something: Chrome or a renderer crashed,
//      a target detached, a load did not fire in time, a CDP call timed out,
//      the CDP connection closed, the run exceeded its wall-clock limit, or
//      any internal error. A broken observation never passes.
//
// Chrome is driven over raw CDP (Node's built-in WebSocket); no automation
// library runs anything inside the page. Each <site-root> is served on
// 127.0.0.1 by a minimal static server, and every .html/.svg/.xml file under it
// is opened in a fresh browser context. A document has a finding on:
//   - any Debugger.scriptParsed event in a page-controlled world. Nothing on
//     this site ever runs script; JSON-LD data blocks are never parsed as
//     script. The single exemption: for .xml documents, Chrome's own XML tree
//     viewer runs in an isolated world that Chrome creates and a page cannot.
//     It is recognised by the execution context (Runtime.executionContextCreated
//     auxData type "isolated", isDefault false), never by script URL, and it
//     does not apply to .html or .svg documents at all.
//   - any request whose URL is not on the local server's origin (data:, blob:
//     and every other scheme included); off-origin requests are also blocked.
//     Exemption: the XML viewer's own arrow icons, matched byte-for-byte.
//   - any console API call, uncaught exception, Log entry (CSP violations,
//     failed loads, deprecations) or HTTP error status on the local server
//   - a navigation away from the document, at any time while it is observed
// Chrome's automatic /favicon.ico probe for documents that declare no icon
// (standalone SVG/XML) is not a finding.
//
// Test-only knobs (they can only make a run fail, never pass):
//   SITE_OBSERVE_LOAD_TIMEOUT_MS  shorten the load timeout
//   SITE_OBSERVE_FAULT=renderer|browser  crash the renderer / kill Chrome
//                                        after the first document loads
//   SITE_OBSERVE_FAULT=hang              hold every subresource request open
//                                        forever, as a stuck server would
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { rmSync } from "node:fs";
import { mkdtemp, readFile, readdir, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import { extname, join, relative, resolve, sep } from "node:path";

const SETTLE_MS = 2500;
const LOAD_TIMEOUT_MS = Math.min(Number(process.env.SITE_OBSERVE_LOAD_TIMEOUT_MS) || 20000, 20000);
const CDP_TIMEOUT_MS = 15000;
const RUN_TIMEOUT_MS = 10 * 60 * 1000;
const FAULT = process.env.SITE_OBSERVE_FAULT ?? "";
const DOC_EXTS = new Set([".html", ".svg", ".xml"]);
// Chrome's XML tree viewer (third_party/blink/renderer/core/xml/xml_viewer.css)
// draws its expand/collapse arrows with exactly these two data: URLs.
const XML_VIEWER_ICONS = new Set([
  "data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' fill='%23909090' width='10' height='10'><path d='M0 0 L8 0 L4 7 Z'/></svg>",
  "data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' fill='%23909090' width='10' height='10'><path d='M0 0 L0 8 L7 4 Z'/></svg>",
]);
const TYPES = {
  ".html": "text/html; charset=utf-8",
  ".svg": "image/svg+xml",
  ".xml": "application/xml; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".png": "image/png",
  ".webp": "image/webp",
  ".avif": "image/avif",
  ".ico": "image/x-icon",
  ".txt": "text/plain; charset=utf-8",
  ".json": "application/json",
  ".webmanifest": "application/manifest+json",
};

// ---- fail-closed process state ----
const servers = new Set();
let chrome = null;
let shuttingDown = false;

function cleanup() {
  if (shuttingDown) return;
  shuttingDown = true;
  for (const s of servers) {
    s.closeAllConnections?.();
    s.close();
  }
  servers.clear();
  if (chrome && chrome.proc.exitCode === null) chrome.proc.kill("SIGKILL");
  if (chrome) rmSync(chrome.profile, { recursive: true, force: true });
}

// Exit 2: something could not be observed.
function unobservable(reason) {
  if (shuttingDown) return; // normal exit already in progress
  console.error(`site-observe: could not observe: ${reason}`);
  cleanup();
  process.exit(2);
}

process.on("uncaughtException", (err) => unobservable(`internal error: ${err?.stack ?? err}`));
process.on("unhandledRejection", (err) => unobservable(`internal error: ${err?.stack ?? err}`));
const runTimer = setTimeout(() => unobservable(`run exceeded ${RUN_TIMEOUT_MS} ms`), RUN_TIMEOUT_MS);
if (typeof WebSocket !== "function") unobservable("this Node has no global WebSocket (needs the pinned Node 24)");

const [chromePath, ...roots] = process.argv.slice(2);
if (!chromePath || roots.length === 0) {
  console.error("usage: site-observe.mjs <chrome-path> <site-root>...");
  process.exit(64);
}

async function walk(dir) {
  const out = [];
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) out.push(...(await walk(full)));
    else out.push(full);
  }
  return out;
}

function serve(root) {
  const server = createServer(async (req, res) => {
    try {
      const path = decodeURIComponent(new URL(req.url, "http://x").pathname);
      let file = resolve(root, "." + path);
      if (file !== root && !file.startsWith(root + sep)) throw new Error("outside root");
      if ((await stat(file)).isDirectory()) file = join(file, "index.html");
      const body = await readFile(file);
      res.writeHead(200, { "content-type": TYPES[extname(file).toLowerCase()] ?? "application/octet-stream" });
      res.end(body);
    } catch {
      res.writeHead(404, { "content-type": "text/plain" });
      res.end("not found");
    }
  });
  servers.add(server);
  return new Promise((ok) => server.listen(0, "127.0.0.1", () => ok(server)));
}

async function launchChrome() {
  const profile = await mkdtemp(join(tmpdir(), "site-observe-"));
  const proc = spawn(
    chromePath,
    [
      "--headless=new",
      "--no-sandbox",
      "--disable-gpu",
      "--no-first-run",
      "--no-default-browser-check",
      "--disable-background-networking",
      "--disable-component-update",
      "--disable-extensions",
      "--remote-debugging-port=0",
      `--user-data-dir=${profile}`,
      "about:blank",
    ],
    { stdio: ["ignore", "ignore", "pipe"] },
  );
  chrome = { proc, profile };
  proc.on("exit", (code, signal) => unobservable(`Chrome exited (code ${code}, signal ${signal})`));
  proc.on("error", (err) => unobservable(`Chrome failed to start: ${err.message}`));
  const wsUrl = await new Promise((ok) => {
    let buf = "";
    const timer = setTimeout(() => unobservable("Chrome did not start within 30 s"), 30000);
    proc.stderr.on("data", (d) => {
      buf += d.toString();
      const m = buf.match(/DevTools listening on (ws:\/\/\S+)/);
      if (m) {
        clearTimeout(timer);
        ok(m[1]);
      }
    });
  });
  return wsUrl;
}

// Minimal flat-session CDP client. Every call has a timeout; a closed or
// failed connection rejects every pending call and ends the run with exit 2.
function connect(wsUrl) {
  const ws = new WebSocket(wsUrl);
  let nextId = 0;
  const pending = new Map();
  const listeners = new Set();
  const dead = (reason) => {
    for (const { fail } of pending.values()) fail(new Error(reason));
    pending.clear();
    unobservable(reason);
  };
  ws.addEventListener("message", (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.id !== undefined && pending.has(msg.id)) {
      const { ok, fail } = pending.get(msg.id);
      pending.delete(msg.id);
      if (msg.error) fail(new Error(`${msg.error.message} (${msg.error.code})`));
      else ok(msg.result);
    } else if (msg.method) {
      for (const l of listeners) l(msg);
    }
  });
  ws.addEventListener("close", () => dead("CDP connection closed"));
  ws.addEventListener("error", () => dead("CDP connection error"));
  const send = (method, params = {}, sessionId = undefined) =>
    new Promise((ok, fail) => {
      nextId += 1;
      const id = nextId;
      const timer = setTimeout(() => {
        pending.delete(id);
        fail(new Error(`CDP ${method} timed out after ${CDP_TIMEOUT_MS} ms`));
      }, CDP_TIMEOUT_MS);
      pending.set(id, {
        ok: (v) => {
          clearTimeout(timer);
          ok(v);
        },
        fail: (e) => {
          clearTimeout(timer);
          fail(e);
        },
      });
      ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
    });
  const opened = new Promise((ok) => ws.addEventListener("open", () => ok()));
  return { opened, send, on: (l) => listeners.add(l), off: (l) => listeners.delete(l) };
}

async function observe(cdp, origin, url, isXml) {
  const problems = [];
  const probe = `${origin}/favicon.ico`;
  const { browserContextId } = await cdp.send("Target.createBrowserContext", { disposeOnDetach: true });
  const { targetId } = await cdp.send("Target.createTarget", { url: "about:blank", browserContextId });
  const { sessionId } = await cdp.send("Target.attachToTarget", { targetId, flatten: true });
  const contexts = new Map(); // executionContextId -> auxData
  let mainFrameId = "";
  let loaded = false;
  let resolveLoad = () => {};
  const loadFired = new Promise((ok) => {
    resolveLoad = ok;
  });
  const onEvent = (msg) => {
    const p = msg.params ?? {};
    // Lifecycle events that make the observation incomplete: exit 2.
    if (msg.method === "Target.targetCrashed" && p.targetId === targetId) unobservable(`renderer crashed (${url})`);
    if (msg.method === "Target.detachedFromTarget" && p.sessionId === sessionId) unobservable(`target detached (${url})`);
    if (msg.sessionId !== sessionId) return;
    switch (msg.method) {
      case "Inspector.targetCrashed":
        unobservable(`renderer crashed (${url})`);
        break;
      case "Inspector.detached":
        unobservable(`inspector detached: ${p.reason} (${url})`);
        break;
      case "Page.loadEventFired":
        resolveLoad();
        break;
      case "Runtime.executionContextCreated":
        contexts.set(p.context.id, p.context.auxData ?? {});
        break;
      case "Debugger.scriptParsed": {
        const aux = contexts.get(p.executionContextId);
        const viewer = isXml && aux !== undefined && aux.type === "isolated" && aux.isDefault === false;
        if (!viewer) problems.push(`script parsed: ${p.url || "(inline)"} in context ${p.executionContextId}`);
        break;
      }
      case "Runtime.consoleAPICalled":
        problems.push(`console.${p.type}: ${(p.args ?? []).map((a) => a.value ?? a.description).join(" ")}`);
        break;
      case "Runtime.exceptionThrown":
        problems.push(`exception: ${p.exceptionDetails.text}`);
        break;
      case "Log.entryAdded":
        if (p.entry.url !== probe) problems.push(`log ${p.entry.level}: ${p.entry.text}`);
        break;
      case "Network.requestWillBeSent": {
        let reqOrigin = "";
        try {
          reqOrigin = new URL(p.request.url).origin;
        } catch {
          reqOrigin = "";
        }
        const viewerIcon = isXml && XML_VIEWER_ICONS.has(p.request.url);
        if (reqOrigin !== origin && !viewerIcon) {
          problems.push(`request to another origin: ${p.request.url.slice(0, 160)}`);
        }
        break;
      }
      case "Network.responseReceived":
        if (p.response.url.startsWith(origin) && p.response.status >= 400 && p.response.url !== probe) {
          problems.push(`HTTP ${p.response.status}: ${p.response.url}`);
        }
        break;
      case "Fetch.requestPaused": {
        if (FAULT === "hang" && p.request.url !== url) break; // never answered
        const allowed = p.request.url.startsWith(origin + "/");
        const method = allowed ? "Fetch.continueRequest" : "Fetch.failRequest";
        const params = allowed ? { requestId: p.requestId } : { requestId: p.requestId, errorReason: "BlockedByClient" };
        // A request that was already cancelled cannot be continued; that is fine.
        cdp.send(method, params, sessionId).catch(() => {});
        break;
      }
      case "Page.frameNavigated":
        if (!p.frame.parentId) {
          if (loaded) problems.push(`navigated away to ${p.frame.url}`);
          mainFrameId = p.frame.id;
        }
        break;
      case "Page.frameRequestedNavigation":
      case "Page.frameScheduledNavigation":
        if (loaded) problems.push(`navigation requested to ${p.url}`);
        break;
      default:
        break;
    }
  };
  cdp.on(onEvent);
  try {
    for (const domain of ["Inspector", "Page", "Runtime", "Debugger", "Network", "Log"]) {
      await cdp.send(`${domain}.enable`, {}, sessionId);
    }
    await cdp.send("Fetch.enable", { patterns: [{ urlPattern: "*" }] }, sessionId);
    const nav = await cdp.send("Page.navigate", { url }, sessionId);
    if (nav.errorText) problems.push(`navigation failed: ${nav.errorText}`);
    let loadTimer = null;
    await Promise.race([
      loadFired,
      new Promise((ok) => {
        loadTimer = setTimeout(() => unobservable(`load event did not fire within ${LOAD_TIMEOUT_MS} ms (${url})`), LOAD_TIMEOUT_MS);
        loadFired.then(ok);
      }),
    ]);
    clearTimeout(loadTimer);
    loaded = true;
    if (FAULT === "renderer") await cdp.send("Page.crash", {}, sessionId).catch(() => {});
    if (FAULT === "browser") chrome.proc.kill("SIGKILL");
    await new Promise((ok) => setTimeout(ok, SETTLE_MS));
    if (!mainFrameId) unobservable(`document never committed (${url})`);
  } finally {
    cdp.off(onEvent);
  }
  await cdp.send("Target.closeTarget", { targetId });
  await cdp.send("Target.disposeBrowserContext", { browserContextId });
  return problems;
}

const wsUrl = await launchChrome();
const cdp = connect(wsUrl);
await cdp.opened;
// Browser-level target events (crash, detach) arrive on the root session.
await cdp.send("Target.setDiscoverTargets", { discover: true });
let failed = 0;
let observed = 0;
for (const rootArg of roots) {
  const root = resolve(rootArg);
  const server = await serve(root);
  const origin = `http://127.0.0.1:${server.address().port}`;
  for (const file of (await walk(root)).sort()) {
    if (!DOC_EXTS.has(extname(file).toLowerCase())) continue;
    const rel = relative(root, file).split(sep).map(encodeURIComponent).join("/");
    const isXml = extname(file).toLowerCase() === ".xml";
    const problems = await observe(cdp, origin, `${origin}/${rel}`, isXml);
    observed += 1;
    for (const p of problems) console.error(`site-observe: ${rootArg}/${relative(root, file)}: ${p}`);
    if (problems.length > 0) failed += 1;
  }
  servers.delete(server);
  server.closeAllConnections?.();
  server.close();
}
clearTimeout(runTimer);
if (observed === 0) unobservable("no documents found");
console.log(`site-observe: ${observed} documents fully observed in Chrome, ${failed} with findings`);
const code = failed > 0 ? 1 : 0;
cleanup();
process.exit(code);
