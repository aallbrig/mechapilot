// Serve a built site root on 127.0.0.1 (an ephemeral port) with the same
// static server scripts/site-observe uses, so scripts/website-eval/collect can
// measure a local build over HTTP. Prints the root URL on one line once
// listening, then serves until SIGTERM, SIGINT or SIGHUP.
// Usage: node scripts/website-eval/serve.mjs <site-root>
import { statSync } from "node:fs";
import { createStaticServer } from "../lib-static-server.mjs";

const [root] = process.argv.slice(2);
if (!root || !statSync(root, { throwIfNoEntry: false })?.isDirectory()) {
  console.error("usage: serve.mjs <site-root> (an existing directory)");
  process.exit(64);
}
const server = createStaticServer(root);
const stop = () => {
  server.closeAllConnections();
  server.close(() => process.exit(0));
};
for (const signal of ["SIGTERM", "SIGINT", "SIGHUP"]) process.on(signal, stop);
server.listen(0, "127.0.0.1", () => {
  console.log(`http://127.0.0.1:${server.address().port}/`);
});
