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

# before = the text just in front of the token, for context.
function classify(kind, tok, before,    n, lower, last, parts, prefix, digits, path) {
  if (kind == "arn") return ph("arn", tok)
  if (kind == "email") return ph("email", tolower(tok))
  if (kind == "uuid") return ph("resource-id", tolower(tok))
  if (kind == "ipv4") return ph("ip", tok)
  if (kind == "ipv6") {
    # Compressed (::) or full eight-group form; times like 12:00:00 are neither.
    n = gsub(/:/, ":", tok)
    if ((index(tok, "::") > 0 && length(tok) > 2) || n == 7) return ph("ip", tolower(tok))
    return ""
  }
  if (kind == "iam-session") {
    # AROA...:<session-name> from a caller identity: the session name is often a
    # username, so the ID and the name go together.
    return ph("iam-id", tok)
  }
  if (kind == "account-sep") {
    # 1234-5678-9012 and 1234 5678 9012 as the console and bills print them,
    # and the same with ".", "_" or "/". Runs of 12+ digits were replaced first;
    # a group glued to a digit before it is left for the rescan to refuse.
    if (substr(before, length(before), 1) ~ /[0-9]/) return ""
    digits = tok
    gsub(/[^0-9]/, "", digits)
    return ph("account", digits)
  }
  if (kind == "digits") {
    n = length(tok)
    if (n == 12) return ph("account", tok)
    if (n > 12) return ph("number", tok)
    return ""
  }
  if (kind == "upper") {
    n = length(tok)
    prefix = substr(tok, 1, 4)
    # Access key IDs are 20 characters; role, user and group unique IDs 21.
    if ((n == 20 || n == 21) && (prefix in iam_prefix)) return ph("iam-id", tok)
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
    # A label of letters, or a punycode label (xn--...), can be a TLD.
    if (length(last) < 2 || (last !~ /^[a-z]+$/ && last !~ /^xn--[a-z0-9-]+$/)) return ""
    if (lower == domain || substr(lower, length(lower) - length(domain)) == "." domain) return ""
    if (lower in safe_host) return ""
    # Extensions that are not TLDs are never hosts (report.json, a.b.yml).
    if (last in file_ext) return ""
    # Extensions that are also TLDs: a file name only with exactly two labels
    # and only as a path component (after "/", but not the "//" of a URL), as
    # in infra/main.tf. a/b.evil.sh, build.corp.md and bare SKILL.md are redacted.
    path = substr(before, length(before), 1) == "/" && substr(before, length(before) - 1, 1) != "/"
    if (path && n == 2 && (last in tld_ext)) return ""
    return ph("host", lower)
  }
  return ""
}

function scan(s, re, kind,    out, tok, r) {
  out = ""
  while (match(s, re)) {
    tok = substr(s, RSTART, RLENGTH)
    out = out substr(s, 1, RSTART - 1)
    r = classify(kind, tok, out)
    out = out (r == "" ? tok : r)
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
  # File extensions that are not TLDs: never a hostname.
  split("json jq awk txt yml yaml toml tfvars hcl html htm js mjs css png svg jpg xml tsv csv", a, " ")
  for (i in a) file_ext[a[i]] = 1
  # File extensions that are also TLDs: a file name only in a path.
  split("md sh tf gd log", a, " ")
  for (i in a) tld_ext[a[i]] = 1

  h = "[0-9A-Fa-f]"
  d = "[0-9]"
  re_uuid = rep(h, 8) "-" rep(h, 4) "-" rep(h, 4) "-" rep(h, 4) "-" rep(h, 12)
  re_account_sep = rep(d, 4) "[-. _/]" rep(d, 4) "[-. _/]" rep(d, 4)
  re_iam_session = "(AKIA|ASIA|AROA|AIDA|AGPA|ANPA|ANVA|AIPA|APKA|ABIA|ACCA)[A-Z0-9]+:[^ \t\"'`,<>(){}|]+"
  re_arn = "arn:aws[-a-z]*:[^ \t\"'`,<>(){}|]*"
  re_email = "[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+([.][A-Za-z0-9-]+)+"
  re_ipv4 = "[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+"
  re_ipv6 = "[0-9A-Fa-f:]+"
  re_host = "[A-Za-z0-9-]+([.][A-Za-z0-9-]+)+"
}

{
  s = literals_out($0)
  s = scan(s, re_arn, "arn")
  s = scan(s, re_email, "email")
  s = scan(s, re_uuid, "uuid")
  s = scan(s, re_iam_session, "iam-session")
  s = scan(s, re_ipv4, "ipv4")
  s = scan(s, re_ipv6, "ipv6")
  s = scan(s, "[0-9]+", "digits")
  s = scan(s, re_account_sep, "account-sep")
  s = scan(s, re_host, "host")
  s = scan(s, "[A-Z0-9]+", "upper")
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
