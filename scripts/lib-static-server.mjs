// A minimal static file server for a built site root, shared by
// scripts/site-observe.mjs and scripts/website-eval/serve.mjs so both serve a
// build the same way. Directories resolve to index.html; anything outside the
// root, or missing, is a 404. It sets no response headers beyond content-type.
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { extname, join, resolve, sep } from "node:path";

export const TYPES = {
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

// Return an http.Server (not yet listening) that serves the files under rootArg.
export function createStaticServer(rootArg) {
  const root = resolve(rootArg);
  return createServer(async (req, res) => {
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
}
