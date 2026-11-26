# Replace identifiers with stable placeholders such as [account-1] and [host-2].
# Run by scripts/aws-eval/redact; POSIX awk with no regex intervals (BWK awk and
# older mawk lack them), so fixed-length patterns are built by rep().
# Variables: literals = file of "kind<TAB>value" lines (longest first),
# domain = the public domain whose hostnames stay, mode = "redact" or "check".
# In check mode nothing is printed; residual kinds go to stderr and the exit is 1.

function rep(s, n,    out, i) {
  out = ""
  for (i = 0; i < n; i++) out = out s
  return out
}

# The same value always gets the same placeholder within one run.
function ph(kind, value,    key) {
  hits[kind]++
  key = kind SUBSEP value
  if (!(key in map)) {
    count[kind]++
    map[key] = "[" kind "-" count[kind] "]"
  }
  return map[key]
}

function classify(kind, tok,    n, lower, last, parts, prefix) {
  if (kind == "arn") return ph("arn", tok)
  if (kind == "email") return ph("email", tolower(tok))
  if (kind == "uuid") return ph("resource-id", tolower(tok))
  if (kind == "digits") {
    n = length(tok)
    if (n == 12) return ph("account", tok)
    if (n > 12) return ph("number", tok)
    return ""
  }
  if (kind == "upper") {
    n = length(tok)
    prefix = substr(tok, 1, 4)
    if (n == 20 && (prefix in iam_prefix)) return ph("iam-id", tok)
    # CloudFront distribution, OAC and key IDs.
    if (substr(tok, 1, 1) == "E" && (n == 13 || n == 14)) return ph("resource-id", tok)
    # Route 53 hosted zone IDs.
    if (substr(tok, 1, 1) == "Z" && n >= 10 && n <= 32) return ph("resource-id", tok)
    return ""
  }
  if (kind == "host") {
    lower = tolower(tok)
    n = split(lower, parts, ".")
    last = parts[n]
    if (length(last) < 2 || last !~ /^[a-z]+$/) return ""
    if (last in file_ext) return ""
    if (lower == domain || substr(lower, length(lower) - length(domain)) == "." domain) return ""
    if (lower in safe_host) return ""
    return ph("host", lower)
  }
  return ""
}

function scan(s, re, kind,    out, tok, r) {
  out = ""
  while (match(s, re)) {
    tok = substr(s, RSTART, RLENGTH)
    r = classify(kind, tok)
    out = out substr(s, 1, RSTART - 1) (r == "" ? tok : r)
    s = substr(s, RSTART + RLENGTH)
  }
  return out s
}

function literals_out(s,    i, at, out) {
  for (i = 1; i <= nlit; i++) {
    out = ""
    while ((at = index(s, lit_val[i])) > 0) {
      out = out substr(s, 1, at - 1) ph(lit_kind[i], lit_val[i])
      s = substr(s, at + length(lit_val[i]))
    }
    s = out s
  }
  return s
}

BEGIN {
  domain = tolower(domain)
  nlit = 0
  if (literals != "") {
    while ((getline line < literals) > 0) {
      tab = index(line, "\t")
      if (tab == 0) continue
      nlit++
      lit_kind[nlit] = substr(line, 1, tab - 1)
      lit_val[nlit] = substr(line, tab + 1)
    }
    close(literals)
  }
  split("AKIA ASIA AROA AIDA AGPA ANPA ANVA AIPA APKA ABIA ACCA", a, " ")
  for (i in a) iam_prefix[a[i]] = 1
  # Generic service hostnames that identify nothing about this account.
  split("amazonaws.com sts.amazonaws.com s3.amazonaws.com cloudfront.net aws.amazon.com docs.aws.amazon.com " \
    "token.actions.githubusercontent.com github.com", a, " ")
  for (i in a) safe_host[a[i]] = 1
  # Dotted names that are file names, not hosts (several are also real TLDs).
  split("json md sh jq awk txt yml yaml toml tf tfvars hcl html htm js mjs css gd png svg jpg xml tsv csv log", a, " ")
  for (i in a) file_ext[a[i]] = 1

  h = "[0-9A-Fa-f]"
  re_uuid = rep(h, 8) "-" rep(h, 4) "-" rep(h, 4) "-" rep(h, 4) "-" rep(h, 12)
  re_arn = "arn:aws[-a-z]*:[^ \t\"'`,<>(){}|]*"
  re_email = "[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+([.][A-Za-z0-9-]+)+"
  re_host = "[A-Za-z0-9-]+([.][A-Za-z0-9-]+)+"
}

{
  s = literals_out($0)
  s = scan(s, re_arn, "arn")
  s = scan(s, re_email, "email")
  s = scan(s, re_uuid, "uuid")
  s = scan(s, re_host, "host")
  s = scan(s, "[A-Z0-9]+", "upper")
  s = scan(s, "[0-9]+", "digits")
  if (mode != "check") print s
}

END {
  if (mode == "check") {
    status = 0
    for (k in hits) {
      printf "redact: residual %s (%d)\n", k, hits[k] > "/dev/stderr"
      status = 1
    }
    exit status
  }
}
