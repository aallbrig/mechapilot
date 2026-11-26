# Scoring rules for scripts/website-eval/score: pure jq over the raw tool
# outputs of one scripts/website-eval/collect run, to one report
# (schemas/website-eval.schema.json). This file is the single source of the
# thresholds; every check in the report carries the threshold it was judged by.
#
# Arguments: $now (ISO 8601 UTC), $headers (raw `curl -D` text), and slurped
# $meta, $lh (Lighthouse JSON), $hv (html-validate JSON), $ly (lychee JSON),
# $tls (scripts/website-eval/tls.mjs JSON, or null when not measured).
#
# Verdicts: pass, warn, fail, or not_applicable (the dimension can't be judged
# for this target: response headers and TLS on a local build, whose server is
# not the production edge). A dimension's verdict is its worst check's; the
# report's verdict is its worst dimension's. not_applicable never hides a
# fail: it is ignored unless every check is not_applicable.
#
# Numeric thresholds: {direction, pass, warn}. "lower" is better: value <= pass
# is pass, value <= warn is warn, else fail. "higher" is better: value >= pass
# is pass, value >= warn is warn, else fail. A missing value (null) is fail.

def thresholds: {
  # Lighthouse's own colour bands: green from 90, orange from 50.
  "lighthouse.category":              {direction: "higher", pass: 0.9, warn: 0.5, unit: "score"},
  # Core Web Vitals (lab): web.dev "good" / "needs improvement" bounds; TBT is
  # the lab stand-in for INP, with Lighthouse's own bands.
  "core_web_vitals.largest_contentful_paint": {direction: "lower", pass: 2500, warn: 4000, unit: "ms"},
  "core_web_vitals.cumulative_layout_shift":  {direction: "lower", pass: 0.1, warn: 0.25, unit: "unitless"},
  "core_web_vitals.total_blocking_time":      {direction: "lower", pass: 200, warn: 600, unit: "ms"},
  "core_web_vitals.first_contentful_paint":   {direction: "lower", pass: 1800, warn: 3000, unit: "ms"},
  "core_web_vitals.speed_index":              {direction: "lower", pass: 3400, warn: 5800, unit: "ms"},
  # axe-core (run by Lighthouse): any violated rule fails.
  "accessibility.violations":         {direction: "lower", pass: 0, warn: 0, unit: "count"},
  # html-validate with the repo's .htmlvalidate.json.
  "html.errors":                      {direction: "lower", pass: 0, warn: 0, unit: "count"},
  "html.warnings":                    {direction: "lower", pass: 0, warn: 10, unit: "count"},
  # lychee: broken links fail; timeouts warn up to 3; a page with no checked
  # link warns: confirm the page really has none before trusting the pass.
  "links.broken":                     {direction: "lower", pass: 0, warn: 0, unit: "count"},
  "links.timeouts":                   {direction: "lower", pass: 0, warn: 3, unit: "count"},
  "links.checked":                    {direction: "higher", pass: 1, warn: 0, unit: "count"},
  # Page weight (Lighthouse resource-summary, transfer sizes).
  "weight.total_bytes":               {direction: "lower", pass: 512000, warn: 1638400, unit: "bytes"},
  "weight.requests":                  {direction: "lower", pass: 25, warn: 50, unit: "count"},
  "weight.third_party_requests":      {direction: "lower", pass: 0, warn: 3, unit: "count"},
  # HSTS max-age: a year passes (the preload minimum); any shorter max-age warns.
  "security_headers.strict_transport_security": {direction: "higher", pass: 31536000, warn: 1, unit: "seconds"},
  # TLS: ACM renews 60 days ahead, so under 30 days left means renewal is stuck.
  "tls.days_remaining":               {direction: "higher", pass: 30, warn: 14, unit: "days"},
  "tls.chain_trusted":                {direction: "higher", pass: 1, warn: 1, unit: "boolean"}
};

# Rules for the checks that are not a number on a scale.
def rules: {
  "security_headers.content_security_policy": "pass: a Content-Security-Policy header with default-src or script-src and neither 'unsafe-inline' nor 'unsafe-eval'; warn: present but weaker; fail: missing",
  "security_headers.x_content_type_options": "pass: X-Content-Type-Options is exactly nosniff; fail: anything else or missing",
  "security_headers.frame_ancestors": "pass: the CSP header has a frame-ancestors directive; warn: only X-Frame-Options DENY or SAMEORIGIN; fail: neither",
  "security_headers.referrer_policy": "pass: no-referrer, same-origin, strict-origin or strict-origin-when-cross-origin; warn: missing or another value; fail: unsafe-url or no-referrer-when-downgrade"
};

# Fix ranking: fail before warn, then this dimension order, then check id.
def dimension_order: ["security_headers", "tls", "accessibility", "links", "html", "core_web_vitals", "lighthouse", "weight"];

def severity: {"fail": 2, "warn": 1, "pass": 0, "not_applicable": -1}[.];

def judge($t):
  if . == null then "fail"
  elif $t.direction == "lower" then
    (if . <= $t.pass then "pass" elif . <= $t.warn then "warn" else "fail" end)
  else
    (if . >= $t.pass then "pass" elif . >= $t.warn then "warn" else "fail" end)
  end;

# A check judged against a numeric threshold. $key names the thresholds entry.
def numeric($id; $key; $title; $value; $evidence):
  thresholds[$key] as $t
  | {id: $id, title: $title, value: $value, unit: $t.unit,
     threshold: {direction: $t.direction, pass: $t.pass, warn: $t.warn},
     verdict: ($value | judge($t)), evidence: $evidence};

def categorical($id; $title; $value; $verdict; $evidence):
  {id: $id, title: $title, value: $value, unit: "text", threshold: {rule: rules[$id]},
   verdict: $verdict, evidence: $evidence};

def not_applicable($why):
  .verdict = "not_applicable" | .evidence = [$why];

def worst: map(.verdict) | map(select(. != "not_applicable"))
  | if length == 0 then "not_applicable" else max_by(severity) end;

# ---- inputs ----

def lhr:
  if $lh[0].runtimeError != null then error("Lighthouse runtime error: \($lh[0].runtimeError.code)") else $lh[0] end;

def audit($id): lhr.audits[$id] // error("Lighthouse report has no audit \($id)");

# Failing scored audits in a category, worst first (manual, informative and
# not-applicable audits carry no score).
def failing_audits($category):
  [lhr.categories[$category].auditRefs[] | .id as $id | lhr.audits[$id]
   | select(.score != null and .score < 1 and (.scoreDisplayMode == "binary" or .scoreDisplayMode == "numeric" or .scoreDisplayMode == "metricSavings"))
   | {id, score}] | sort_by(.score, .id) | map("\(.id) (\(.score))");

# The last response block of `curl -D` (after any redirects), as {name: value}
# with lower-case names; a repeated header's values are joined with ", ".
def response_headers:
  ($headers | gsub("\r"; "") | split("\n")) as $lines
  | ([$lines | to_entries[] | select(.value | test("^HTTP/")) | .key] | last) as $start
  | if $start == null then error("no HTTP response in the captured headers") else . end
  | [$lines[($start + 1):][] | select(test("^[!#$%&'*+.^_`|~0-9A-Za-z-]+:"))
     | capture("^(?<name>[^:]+):[ \t]*(?<value>.*?)[ \t]*$") | .name |= ascii_downcase]
  | group_by(.name) | map({key: .[0].name, value: (map(.value) | join(", "))}) | from_entries;

def csp_directives:
  (. // "") | ascii_downcase | split(",") | map(split(";")[]) | map(gsub("^\\s+|\\s+$"; "") | split(" ")[0]) | map(select(. != ""));

# ---- dimensions ----

def lighthouse_checks:
  [lhr.categories | to_entries[] | .key as $c
   | numeric("lighthouse.\($c)"; "lighthouse.category"; "Lighthouse \(.value.title)"; .value.score; failing_audits($c))];

def cwv_checks:
  [
    numeric("core_web_vitals.largest_contentful_paint"; "core_web_vitals.largest_contentful_paint"; "Largest Contentful Paint (lab)"; audit("largest-contentful-paint").numericValue; []),
    numeric("core_web_vitals.cumulative_layout_shift"; "core_web_vitals.cumulative_layout_shift"; "Cumulative Layout Shift (lab)"; audit("cumulative-layout-shift").numericValue; []),
    numeric("core_web_vitals.total_blocking_time"; "core_web_vitals.total_blocking_time"; "Total Blocking Time (lab stand-in for INP)"; audit("total-blocking-time").numericValue; []),
    numeric("core_web_vitals.first_contentful_paint"; "core_web_vitals.first_contentful_paint"; "First Contentful Paint (lab)"; audit("first-contentful-paint").numericValue; []),
    numeric("core_web_vitals.speed_index"; "core_web_vitals.speed_index"; "Speed Index (lab)"; audit("speed-index").numericValue; [])
  ];

def accessibility_checks:
  [lhr.categories.accessibility.auditRefs[] | .id as $id | lhr.audits[$id]
   | select(.scoreDisplayMode == "binary" and .score == 0)
   | "\($id): \(.title) (\(.details.items // [] | length) elements)"] as $violations
  | [numeric("accessibility.violations"; "accessibility.violations"; "axe-core rule violations"; ($violations | length); $violations)];

def html_checks:
  [$hv[0][]?.messages[]?] as $m
  | [$m[] | select(.severity == 2)] as $errors
  | [$m[] | select(.severity == 1)] as $warnings
  | def lines: map("\(.ruleId) line \(.line): \(.message)");
  [
    numeric("html.errors"; "html.errors"; "html-validate errors"; ($errors | length); ($errors | lines)),
    numeric("html.warnings"; "html.warnings"; "html-validate warnings"; ($warnings | length); ($warnings | lines))
  ];

def links_checks:
  $ly[0] as $r
  | def failures($map): [$r[$map] // {} | to_entries[] | .value[] | "\(.url): \(.status.text // .status.code // "failed")"];
  [
    numeric("links.broken"; "links.broken"; "Broken links"; $r.errors; failures("error_map")),
    numeric("links.timeouts"; "links.timeouts"; "Links that timed out"; $r.timeouts; failures("timeout_map")),
    numeric("links.checked"; "links.checked"; "Links checked"; $r.successful + $r.errors + $r.timeouts + $r.redirects; [])
  ];

def weight_checks:
  (audit("resource-summary").details.items | map({key: .resourceType, value: .}) | from_entries) as $s
  | [
      numeric("weight.total_bytes"; "weight.total_bytes"; "Page weight (transferred)"; $s.total.transferSize; []),
      numeric("weight.requests"; "weight.requests"; "Requests"; $s.total.requestCount; []),
      numeric("weight.third_party_requests"; "weight.third_party_requests"; "Third-party requests"; $s["third-party"].requestCount; [])
    ];

def header_checks:
  response_headers as $h
  | ($h["content-security-policy"]) as $csp
  | ($csp | csp_directives) as $dirs
  | ($h["strict-transport-security"]) as $hsts
  | ($h["referrer-policy"] // null) as $ref
  | ($ref // "" | ascii_downcase | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(. != "")) | last // "") as $refpol
  | ($h["x-frame-options"] // "" | ascii_downcase | gsub("^\\s+|\\s+$"; "")) as $xfo
  | [
      numeric("security_headers.strict_transport_security"; "security_headers.strict_transport_security";
        "Strict-Transport-Security max-age";
        ($hsts // "" | ascii_downcase | capture("max-age=\"?(?<s>[0-9]+)") | .s | tonumber) // null;
        [if $hsts then "Strict-Transport-Security: \($hsts)" else "header missing" end]),
      categorical("security_headers.content_security_policy"; "Content-Security-Policy header"; $csp;
        if $csp == null then "fail"
        elif ($dirs | index("default-src") or index("script-src")) and ($csp | ascii_downcase | test("'unsafe-(inline|eval)'") | not) then "pass"
        else "warn" end;
        [if $csp == null then "header missing (a <meta> CSP cannot set frame-ancestors or report)" else "Content-Security-Policy: \($csp)" end]),
      categorical("security_headers.x_content_type_options"; "X-Content-Type-Options header"; $h["x-content-type-options"];
        if ($h["x-content-type-options"] // "" | ascii_downcase | gsub("^\\s+|\\s+$"; "")) == "nosniff" then "pass" else "fail" end;
        [if $h["x-content-type-options"] then "X-Content-Type-Options: \($h["x-content-type-options"])" else "header missing" end]),
      categorical("security_headers.frame_ancestors"; "Framing protection (CSP frame-ancestors)";
        ($csp // "" | ascii_downcase | split(";") | map(gsub("^\\s+|\\s+$"; "")) | map(select(startswith("frame-ancestors"))) | first) // $h["x-frame-options"];
        if ($dirs | index("frame-ancestors")) then "pass"
        elif $xfo == "deny" or $xfo == "sameorigin" then "warn"
        else "fail" end;
        [if ($dirs | index("frame-ancestors")) then "CSP has frame-ancestors"
         elif $xfo != "" then "only X-Frame-Options: \($h["x-frame-options"])"
         else "no frame-ancestors and no X-Frame-Options" end]),
      categorical("security_headers.referrer_policy"; "Referrer-Policy header"; $ref;
        if ["no-referrer", "same-origin", "strict-origin", "strict-origin-when-cross-origin"] | index($refpol) then "pass"
        elif $refpol == "unsafe-url" or $refpol == "no-referrer-when-downgrade" then "fail"
        else "warn" end;
        [if $ref then "Referrer-Policy: \($ref)" else "header missing (browsers default to strict-origin-when-cross-origin)" end])
    ]
  | if $meta[0].target.kind == "local" then map(not_applicable("local build: its server is not the production edge, so its headers say nothing"))
    else . end;

def tls_checks:
  $tls[0] as $t
  | ($now | fromdateiso8601) as $n
  | [
      numeric("tls.days_remaining"; "tls.days_remaining"; "Days until the certificate expires";
        (if $t == null then null else (($t.valid_to | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) - $n) / 86400 | floor end);
        [if $t == null then "no TLS: the page was not served over https" else "valid until \($t.valid_to), issued by \($t.issuer // "unknown")" end]),
      numeric("tls.chain_trusted"; "tls.chain_trusted"; "Certificate chain is trusted";
        (if $t == null then null elif $t.authorized then 1 else 0 end);
        [if $t == null then "no TLS: the page was not served over https" elif $t.authorized then "trusted by Node's bundled CAs" else "untrusted: \($t.authorization_error)" end])
    ]
  | if $meta[0].target.kind == "local" then map(not_applicable("local build: served over plain http on 127.0.0.1"))
    else . end;

# ---- report ----

{
  lighthouse: lighthouse_checks,
  core_web_vitals: cwv_checks,
  accessibility: accessibility_checks,
  html: html_checks,
  links: links_checks,
  weight: weight_checks,
  security_headers: header_checks,
  tls: tls_checks
}
| map_values({verdict: worst, checks: .}) as $dims
| [dimension_order[] as $d | $dims[$d].checks[] | select(.verdict == "fail" or .verdict == "warn") | {dimension: $d} + .] as $open
| ($open | sort_by(-(.verdict | severity), (.dimension as $d | dimension_order | index($d)), .id)
  | to_entries | map({rank: (.key + 1), check: .value.id, dimension: .value.dimension, verdict: .value.verdict,
                         title: .value.title, value: .value.value, evidence: .value.evidence})) as $fixes
| [$dims[].checks[].verdict] as $all
| {
    schema_version: 1,
    generated_at: $now,
    target: $meta[0].target,
    tools: ($meta[0].tools + {
      lighthouse: lhr.lighthouseVersion,
      axe_core: (lhr.environment.credits["axe-core"] // null)
    }),
    verdict: ([$dims[]] | worst),
    counts: {
      pass: ($all | map(select(. == "pass")) | length),
      warn: ($all | map(select(. == "warn")) | length),
      fail: ($all | map(select(. == "fail")) | length),
      not_applicable: ($all | map(select(. == "not_applicable")) | length)
    },
    dimensions: $dims,
    fixes: $fixes
  }
