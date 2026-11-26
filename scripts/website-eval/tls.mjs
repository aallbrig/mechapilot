// Read the TLS certificate a host presents and print it as one JSON object:
//   {host, port, protocol, authorized, authorization_error, subject, issuer,
//    valid_from, valid_to}   (scripts/website-eval/score derives the days left)
// The chain is verified against Node's bundled CAs, but an
// unverified chain is still reported (authorized: false), never hidden.
// Usage: node scripts/website-eval/tls.mjs <host> [port]
import { connect } from "node:tls";

const [host, portArg = "443"] = process.argv.slice(2);
const port = Number(portArg);
if (!host || !Number.isInteger(port) || port < 1 || port > 65535) {
  console.error("usage: tls.mjs <host> [port]");
  process.exit(64);
}
const fail = (reason) => {
  console.error(`tls: ${host}:${port}: ${reason}`);
  process.exit(1);
};
const socket = connect({ host, port, servername: host, rejectUnauthorized: false, timeout: 20000 });
socket.on("timeout", () => {
  socket.destroy();
  fail("timed out");
});
socket.on("error", (err) => fail(err.message));
socket.on("secureConnect", () => {
  const cert = socket.getPeerCertificate();
  if (!cert || !cert.valid_to) fail("no peer certificate");
  const validTo = new Date(cert.valid_to);
  const result = {
    host,
    port,
    protocol: socket.getProtocol(),
    authorized: socket.authorized,
    authorization_error: socket.authorizationError ? String(socket.authorizationError) : null,
    subject: cert.subject?.CN ?? null,
    issuer: cert.issuer?.O ?? cert.issuer?.CN ?? null,
    valid_from: new Date(cert.valid_from).toISOString(),
    valid_to: validTo.toISOString(),
  };
  socket.end();
  console.log(JSON.stringify(result));
});
