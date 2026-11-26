# HTML rules for scripts/site-budget (POSIX awk). Input: one flattened,
# case-folded file per record, with tab/CR/LF/FF turned into \001.
function bad(msg) { printf "site-budget: %s: %s\n", page, msg > "/dev/stderr"; failed = 1 }
function hexval(s,   i, n) {
  n = 0
  for (i = 1; i <= length(s); i++) n = n * 16 + index("0123456789abcdef", substr(s, i, 1)) - 1
  return n
}
function chr(n) { return (n > 0 && n < 127) ? sprintf("%c", n) : "?" }
# The URL parser strips leading/trailing C0 controls and spaces before it looks for a scheme.
function trim_url(v) { sub(/^[^!-~]+/, "", v); sub(/[^!-~]+$/, "", v); return v }
function decode(v,   out, i, rest, name, len) {
  gsub(/\001/, "", v)
  out = ""
  while ((i = index(v, "&")) > 0) {
    out = out substr(v, 1, i - 1)
    rest = substr(v, i + 1)
    if (match(rest, /^#x[0-9a-f]+;?/)) {
      len = RLENGTH; name = substr(rest, 3, len - 2); sub(/;$/, "", name)
      out = out chr(hexval(name)); v = substr(rest, len + 1)
    } else if (match(rest, /^#[0-9]+;?/)) {
      len = RLENGTH; name = substr(rest, 2, len - 1); sub(/;$/, "", name)
      out = out chr(name + 0); v = substr(rest, len + 1)
    } else if (match(rest, /^[a-z][a-z0-9]*;?/)) {
      len = RLENGTH; name = substr(rest, 1, len); sub(/;$/, "", name)
      if (name in named) out = out named[name]
      else { bad("unknown character reference &" name ";"); out = out "?" }
      v = substr(rest, len + 1)
    } else { out = out "&"; v = rest }
  }
  out = out v
  gsub(/[\001\t\r\n\f]/, "", out)
  return out
}
function is_ws(c) { return c == " " || c == "\001" }
function check_tag(tag,   a, v, t, ext) {
  if (tag ~ /^(iframe|object|embed|frame|frameset|applet|portal|base|basefont|style|noscript|template|form|isindex|bgsound|xml|import|param|fencedframe|set|animate|animatemotion|animatetransform|animatecolor|discard|foreignobject|handler|listener)$/)
    bad("<" tag "> is not allowed")
  if (tag == "script" && !(nattr == 1 && attrs["type"] == "application/ld+json"))
    bad("only <script type=\"application/ld+json\"> data blocks are allowed")
  if ("http-equiv" in attrs) {
    if (tag == "meta" && nattr == 2 && attrs["http-equiv"] == "content-security-policy" && attrs["content"] == csp) csp_seen = 1
    else bad("<" tag " http-equiv> is only allowed as the site Content-Security-Policy")
  }
  if ("xmlns" in attrs && !((tag == "svg" && attrs["xmlns"] == "http://www.w3.org/2000/svg") ||
      (tag == "urlset" && attrs["xmlns"] == "http://www.sitemaps.org/schemas/sitemap/0.9")))
    bad("xmlns=\"" attrs["xmlns"] "\" is not allowed on <" tag ">")
  for (a in attrs) {
    v = attrs[a]
    if (a ~ /^xmlns:/ || a ~ /:/ && a != "xml:lang") bad("namespaced attribute " a "= on <" tag ">")
    if (a ~ /^on/) bad("event handler " a "= on <" tag ">")
    if (a == "style" || a == "ping" || a == "srcdoc") bad(a "= is not allowed (on <" tag ">)")
    if (v ~ /(javascript|vbscript|livescript)[ ]*:/) bad("script URL in " a "= on <" tag ">")
    # Only same-document references such as fill="url(#gradient)" may use url().
    t = v; gsub(/url\(#[a-z0-9_-]+\)/, "", t)
    if (t ~ /url[^a-z]*\(/ || t ~ /image-set|@import/) bad("url( or CSS load in " a "= on <" tag ">")
    if (a in urlattr) {
      if (v ~ /\\/) bad("backslash in URL " a "= on <" tag ">")
      v = trim_url(v)
      if (v ~ /^data:/) bad("data: URL in " a "= on <" tag ">")
      ext = (v ~ /^([a-z][a-z0-9+.-]*:|\/\/)/) || (a ~ /srcset$/ && v ~ /([a-z][a-z0-9+.-]*:|\/\/)/)
      if (ext && !((tag == "a" && a == "href") || (tag == "link" && a == "href" && attrs["rel"] == "canonical")))
        bad("third-party URL in " a "= on <" tag ">: " v)
    }
  }
}
BEGIN {
  csp = "default-src \047none\047; style-src \047self\047; img-src \047self\047; manifest-src \047self\047; connect-src \047self\047; base-uri \047none\047; form-action \047none\047"
  split("href src srcset imagesrcset poster data action formaction background cite longdesc manifest icon codebase archive classid xlink:href lowsrc dynsrc usemap", u, " ")
  for (k in u) urlattr[u[k]] = 1
  named["amp"] = "&"; named["lt"] = "<"; named["gt"] = ">"; named["quot"] = "\""; named["apos"] = "\047"
  named["tab"] = ""; named["newline"] = ""; named["colon"] = ":"; named["sol"] = "/"; named["bsol"] = "\\"
  named["lpar"] = "("; named["rpar"] = ")"; named["period"] = "."; named["commat"] = "@"; named["num"] = "#"
  named["semi"] = ";"; named["equals"] = "="; named["excl"] = "!"; named["copy"] = "(c)"; named["nbsp"] = " "
  named["middot"] = "."; named["mdash"] = "-"; named["ndash"] = "-"; named["hellip"] = "..."
  named["lsquo"] = "\047"; named["rsquo"] = "\047"; named["ldquo"] = "\""; named["rdquo"] = "\""
}
{
  s = $0; n = length(s); p = 1
  if (index(s, "<!entity") > 0) bad("<!ENTITY declarations are not allowed")
  while (p <= n) {
    i = index(substr(s, p), "<"); if (i == 0) break
    p = p + i
    if (substr(s, p, 3) == "!--") {
      e = index(substr(s, p + 3), "-->"); body = (e ? substr(s, p + 3, e - 1) : substr(s, p + 3))
      if (body ~ /html-validate-|lychee/) bad("tool directive in comment: <!--" body "-->")
      # Browsers end comments at "<!-->", "<!--->" and "--!>"; allow only plain comments.
      if (body ~ /^>|^->|--|-$/ || e == 0) bad("malformed or ambiguous comment: <!--" substr(body, 1, 40))
      p = e ? p + 3 + e + 2 : n + 1; continue
    }
    c = substr(s, p, 1)
    if (c == "?" && substr(s, p, 15) == "?xml-stylesheet") bad("<?xml-stylesheet?> is not allowed")
    if (c == "!" && substr(s, p, 8) == "!doctype") {
      e = index(substr(s, p), ">"); body = (e ? substr(s, p, e - 1) : substr(s, p))
      if (body ~ /\[/) bad("DOCTYPE internal subsets are not allowed")
    }
    if (c !~ /[a-z]/) { if (c == "/" || c == "!" || c == "?") { e = index(substr(s, p), ">"); p = e ? p + e : n + 1 }; continue }
    match(substr(s, p), /^[a-z][^ \001\/>]*/)
    tag = substr(s, p, RLENGTH); p = p + RLENGTH
    # A prefixed name (h:script, s:script, svg:foreignobject) is a namespaced
    # element in XML/SVG documents; none is ever needed, so all are rejected.
    if (tag ~ /:/) bad("namespace-prefixed element <" tag "> is not allowed")
    split("", attrs); nattr = 0
    while (p <= n) {
      c = substr(s, p, 1)
      if (is_ws(c) || c == "/") { p++; continue }
      if (c == ">") { p++; break }
      start = p
      while (p <= n) { c = substr(s, p, 1); if (is_ws(c) || c == "/" || c == ">" || (c == "=" && p > start)) break; p++ }
      name = substr(s, start, p - start); value = ""
      q = p; while (q <= n && is_ws(substr(s, q, 1))) q++
      if (substr(s, q, 1) == "=") {
        p = q + 1; while (p <= n && is_ws(substr(s, p, 1))) p++
        c = substr(s, p, 1)
        if (c == "\"" || c == "\047") {
          e = index(substr(s, p + 1), c); value = (e ? substr(s, p + 1, e - 1) : substr(s, p + 1)); p = e ? p + e + 1 : n + 1
        } else {
          start = p; while (p <= n) { c = substr(s, p, 1); if (is_ws(c) || c == ">") break; p++ }
          value = substr(s, start, p - start)
        }
      }
      if (name in attrs) bad("duplicate attribute " name "= on <" tag ">")
      attrs[name] = decode(value); nattr++
    }
    check_tag(tag)
    # Only <script> (already limited to JSON-LD) has its content skipped: in SVG and
    # MathML, <title>/<textarea>/<style> are ordinary elements whose children parse.
    if (tag == "script") {
      e = index(substr(s, p), "</" tag); p = e ? p + e : n + 1
    }
  }
}
END {
  if (page ~ /\.(html|htm)$/ && !csp_seen) bad("missing the site Content-Security-Policy meta tag")
  exit failed
}
