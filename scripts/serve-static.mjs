// A minimal static file server for build/ (the web export and, later, the sites).
// It sets the MIME types Godot's web export needs (application/wasm enables
// streaming compilation) and never serves a path outside its root.
//
// Usage: node scripts/serve-static.mjs <dir> [port]   (port 0 picks a free one)
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { extname, join, resolve, sep } from "node:path";
import { pathToFileURL } from "node:url";

const TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".txt": "text/plain; charset=utf-8",
};

/**
 * Start serving `dir` on 127.0.0.1:`port`; resolves to { server, url }.
 * `headers` are added to every response (the smoke test sends the Game Site's CSP).
 */
export function serveStatic(dir, port = 0, headers = {}) {
  const root = resolve(dir);
  const server = createServer(async (req, res) => {
    try {
      const path = decodeURIComponent(new URL(req.url ?? "/", "http://x").pathname);
      let file = resolve(join(root, path));
      if (file !== root && !file.startsWith(root + sep)) {
        res.writeHead(403).end("forbidden");
        return;
      }
      const info = await stat(file).catch(() => null);
      if (info?.isDirectory()) file = join(file, "index.html");
      const body = await readFile(file);
      res.writeHead(200, {
        "Content-Type": TYPES[extname(file).toLowerCase()] ?? "application/octet-stream",
        "Cache-Control": "no-store",
        ...headers,
      });
      res.end(body);
    } catch {
      res.writeHead(404).end("not found");
    }
  });
  return new Promise((done, fail) => {
    server.once("error", fail);
    server.listen(port, "127.0.0.1", () => {
      const address = server.address();
      done({ server, url: `http://127.0.0.1:${address.port}/` });
    });
  });
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  const [dir = "build", port = "8060"] = process.argv.slice(2);
  const { url } = await serveStatic(dir, Number(port));
  console.log(`serving ${resolve(dir)} at ${url} (Ctrl-C to stop)`);
}
