# Scoring rules for scripts/aws-eval/score: pure jq over one inventory
# (schemas/aws-eval-inventory.schema.json) to one report
# (schemas/aws-eval-report.schema.json). Arguments: $now (ISO 8601 UTC).
# Each rule yields findings {id, severity, title, resource, detail, remediation}.

def weight: {"critical": 40, "high": 15, "medium": 5, "low": 1}[.];
def rank: {"critical": 0, "high": 1, "medium": 2, "low": 3}[.];

def finding($id; $severity; $title; $resource; $detail; $remediation):
  {id: $id, severity: $severity, title: $title, resource: $resource, detail: $detail, remediation: $remediation};

# Seconds since the epoch from an AWS timestamp (ISO 8601 with Z or +hh:mm, or epoch seconds).
def epoch:
  if type == "number" then .
  else
    . as $raw
    | (capture("^(?<base>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})(?:[.][0-9]+)?(?<tz>Z|[+-][0-9]{2}:[0-9]{2})$") // error("unparseable AWS timestamp: \($raw)")) as $m
    | ($m.base + "Z" | fromdateiso8601)
      - (if $m.tz == "Z" then 0
         else ($m.tz[0:1]) as $sign
           | (($m.tz[1:3] | tonumber) * 3600 + ($m.tz[4:6] | tonumber) * 60) as $off
           | if $sign == "+" then $off else -$off end
         end)
  end;

def now_epoch: $now | epoch;

# ---- S3 ----

def s3_rules:
  .buckets[] as $b
  | (if ($b.policy_status.IsPublic // false) then
       finding("S3_PUBLIC_BUCKET"; "critical"; "S3 bucket is public"; $b.name;
         "The bucket policy status reports IsPublic=true: anyone on the internet can read it.";
         "Make the bucket private and serve it through CloudFront with Origin Access Control.")
     else empty end),
    (($b.public_access_block // {}) as $p
     | if ([$p.BlockPublicAcls, $p.IgnorePublicAcls, $p.BlockPublicPolicy, $p.RestrictPublicBuckets] | all(. == true)) then empty
       else finding("S3_PUBLIC_ACCESS_BLOCK_INCOMPLETE"; "high"; "S3 Block Public Access is not fully on"; $b.name;
         "One or more of the four bucket-level Block Public Access settings is off or missing.";
         "Turn on all four Block Public Access settings for the bucket.")
       end),
    (if $b.encryption == null then
       finding("S3_NO_DEFAULT_ENCRYPTION"; "medium"; "S3 bucket has no default encryption"; $b.name;
         "No server-side encryption configuration was found.";
         "Set default encryption (SSE-S3 or SSE-KMS).")
     else empty end),
    (if ($b.versioning.Status // "") != "Enabled" then
       finding("S3_VERSIONING_OFF"; "low"; "S3 versioning is off"; $b.name;
         "Overwritten or deleted objects cannot be recovered.";
         "Enable versioning, with a lifecycle rule to expire old versions.")
     else empty end),
    (if ($b.logging.LoggingEnabled // null) == null then
       finding("S3_ACCESS_LOGGING_OFF"; "low"; "S3 server access logging is off"; $b.name;
         "Requests to the bucket are not logged.";
         "Enable server access logging, or rely on CloudFront logs once the bucket is private.")
     else empty end);

# ---- CloudFront ----

# Oldest to newest; anything before TLSv1.2_2021 is too old.
def tls_order: ["SSLv3", "TLSv1", "TLSv1_2016", "TLSv1.1_2016", "TLSv1.2_2018", "TLSv1.2_2019", "TLSv1.2_2021", "TLSv1.2_2025", "TLSv1.3_2025"];
def tls_ok: . as $v | (tls_order | index($v)) as $i | $i != null and $i >= (tls_order | index("TLSv1.2_2021"));

def behaviors: [.DefaultCacheBehavior] + (.CacheBehaviors.Items // []);

def s3_origin: (.S3OriginConfig != null) or (.DomainName | test("[.]s3([.-](?!website)[a-z0-9-]+)*[.]amazonaws[.]com$"));

def cloudfront_rules:
  .distributions[] as $d
  | $d.config as $c
  | ($c.ViewerCertificate // {}) as $vc
  | (if ($vc.CloudFrontDefaultCertificate // false) then
       finding("CF_TLS_POLICY_OLD"; "high"; "CloudFront uses the default certificate (TLSv1)"; $d.id;
         "The default *.cloudfront.net certificate allows TLSv1.";
         "Use an ACM certificate with minimum protocol TLSv1.2_2021 or newer.")
     elif (($vc.MinimumProtocolVersion // "") | tls_ok | not) then
       finding("CF_TLS_POLICY_OLD"; "high"; "CloudFront TLS policy is older than TLSv1.2_2021"; $d.id;
         "Minimum protocol version is \($vc.MinimumProtocolVersion // "unset").";
         "Set MinimumProtocolVersion to TLSv1.2_2021 or newer.")
     else empty end),
    (if ([$d.response_headers_policies[]?.SecurityHeadersConfig.StrictTransportSecurity | select(. != null)] | length) == 0 then
       finding("CF_NO_HSTS"; "high"; "CloudFront sends no HSTS header"; $d.id;
         "No attached response headers policy sets Strict-Transport-Security.";
         "Attach a response headers policy with HSTS (max-age at least one year, includeSubdomains).")
     else empty end),
    ($c.Origins.Items[]? | select(s3_origin and ((.OriginAccessControlId // "") == ""))
     | if (.S3OriginConfig.OriginAccessIdentity // "") != "" then
         finding("CF_S3_ORIGIN_LEGACY_OAI"; "medium"; "CloudFront S3 origin uses a legacy Origin Access Identity"; $d.id;
           "Origin \(.Id) reads S3 through an OAI, which AWS has superseded with OAC (no SSE-KMS, no newer regions).";
           "Migrate the origin to an Origin Access Control and drop the OAI grant from the bucket policy.")
       else
         finding("CF_S3_ORIGIN_WITHOUT_OAC"; "high"; "CloudFront S3 origin has no Origin Access Control"; $d.id;
           "Origin \(.Id) reads S3 with neither OAC nor OAI, so the bucket must be readable by anyone.";
           "Attach an Origin Access Control and grant only this distribution in the bucket policy.")
       end),
    ($c.Origins.Items[]? | select(.DomainName | test("[.]s3-website[.-]"))
     | finding("CF_S3_WEBSITE_ORIGIN"; "high"; "CloudFront origin is an S3 website endpoint"; $d.id;
         "Origin \(.Id) uses the S3 website endpoint, which needs a public bucket and cannot use OAC.";
         "Use the S3 REST endpoint with Origin Access Control.")),
    (if ([$c | behaviors[] | select(.ViewerProtocolPolicy == "allow-all")] | length) > 0 then
       finding("CF_HTTP_ALLOWED"; "medium"; "CloudFront allows plain HTTP"; $d.id;
         "A cache behavior uses ViewerProtocolPolicy allow-all.";
         "Use redirect-to-https or https-only on every behavior.")
     else empty end),
    (if ($c.Logging.Enabled // false) | not then
       finding("CF_LOGGING_OFF"; "low"; "CloudFront access logging is off"; $d.id;
         "Requests to the distribution are not logged.";
         "Enable standard logging to a private bucket with a retention lifecycle.")
     else empty end);

# ---- ACM ----

def acm_rules:
  .certificates[] as $cert
  | (if $cert.Status != "ISSUED" then
       finding("ACM_NOT_ISSUED"; "medium"; "ACM certificate is not issued"; $cert.CertificateArn;
         "Status is \($cert.Status).";
         "Validate or delete the certificate.")
     else empty end),
    ($cert.NotAfter // empty
     | ((epoch - now_epoch) / 86400 | floor) as $days
     | if $days < 0 then
        finding("ACM_EXPIRED"; "critical"; "ACM certificate has expired"; $cert.CertificateArn;
          "Expired \(-$days) days ago.";
          "Renew or replace the certificate.")
      elif $days < 30 then
        finding("ACM_EXPIRING"; "high"; "ACM certificate expires within 30 days"; $cert.CertificateArn;
          "Expires in \($days) days; managed renewal may be failing.";
          "Check DNS validation records so managed renewal succeeds.")
       else empty end);

# ---- IAM / GitHub OIDC ----

def oidc_host: "token.actions.githubusercontent.com";

# Values that pin a key, as [{like, value}], taken only from positive operators.
# Negated operators (StringNotEquals, StringNotLike, ...) allow everything except
# the value, and ...IfExists or ForAllValues: pass when the key is missing, so none
# of them pin anything.
def pinning_values($key):
  [(.Condition // {}) | to_entries[]
   | select(.key | test("^(ForAnyValue:)?(StringEquals|StringEqualsIgnoreCase|StringLike)$"))
   | (.key | test("Like$")) as $like
   | .value | to_entries[] | select(.key == $key)
   | .value | (if type == "array" then .[] else . end) | {like: $like, value: .}];

# A policy's statements: AWS allows a single object as well as an array.
def statements: .Statement | if type == "array" then .[] else . end;

def trusts_github_oidc:
  (.Principal | if type == "object" then (.Federated // []) else [] end)
  | (if type == "array" then . else [.] end) | any(endswith(oidc_host));

# "repo:<owner>/<name>:<rest>": the owner/name part must be one literal repository.
# * and ? are wildcards only under a ...Like operator; under StringEquals they are literal.
def repo_part: .value[5:] | split(":")[0];
def wildcard_repo:
  (.value | startswith("repo:") | not)
  or (repo_part | contains("/") | not)
  or (.like and (repo_part | test("[*?]")));
def wildcard_ref: .like and (.value[5:] | split(":")[1:] | join(":") | test("[*?]"));

def iam_rules:
  .oidc_roles[] as $r
  | $r.trust_policy | statements
  | select((.Effect // "Allow") == "Allow" and trusts_github_oidc)
  | pinning_values(oidc_host + ":sub") as $subs
  | pinning_values(oidc_host + ":aud") as $auds
  | (if ($subs | length) == 0 then
       finding("OIDC_TRUST_WITHOUT_SUB"; "critical"; "GitHub OIDC trust has no sub condition"; $r.arn;
         "No positive (StringEquals or StringLike) sub condition: any repository on GitHub can assume this role.";
         "Add a StringEquals condition on token.actions.githubusercontent.com:sub naming this repository.")
     elif ($subs | any(wildcard_repo)) then
       finding("OIDC_TRUST_WILDCARD_REPO"; "critical"; "GitHub OIDC trust allows a wildcard repository"; $r.arn;
         "A sub condition does not pin one repository.";
         "Pin the sub condition to repo:<owner>/<name>:<ref or environment>.")
     elif ($subs | any(wildcard_ref)) then
       finding("OIDC_TRUST_ANY_REF"; "medium"; "GitHub OIDC trust allows any branch or pull request"; $r.arn;
         "The sub condition uses a wildcard after the repository, so any ref can assume the role.";
         "Pin the sub condition to the protected branch or a deployment environment.")
     else empty end),
    (if ($auds | length) == 0 or ($auds | any(.like or .value != "sts.amazonaws.com")) then
       finding("OIDC_TRUST_AUDIENCE"; "high"; "GitHub OIDC trust does not pin the audience to sts.amazonaws.com"; $r.arn;
         "The aud condition is missing or allows another audience.";
         "Add a StringEquals condition token.actions.githubusercontent.com:aud = sts.amazonaws.com.")
     else empty end);

# ---- Logging and retention ----

def logs_rules:
  .log_groups[] | select(.retention_days == null)
  | finding("LOGS_NO_RETENTION"; "low"; "CloudWatch log group keeps logs forever"; .name;
      "No retention period is set.";
      "Set a retention period (for example 90 days).");

# ---- trivy config on infra/ ----

def trivy_rules:
  (.trivy // {}) | .Results[]? as $res
  | $res.Misconfigurations[]? | select(.Status == "FAIL")
  | finding("TRIVY_" + (.ID | gsub("[^A-Za-z0-9]"; "_") | ascii_upcase);
      ({"CRITICAL": "critical", "HIGH": "high", "MEDIUM": "medium"}[.Severity] // "low");
      .Title; $res.Target; .Message; (.Resolution // "See the trivy check documentation."));

# ---- Report ----

[s3_rules, cloudfront_rules, acm_rules, iam_rules, logs_rules, trivy_rules] as $all
| ($all | unique | sort_by((.severity | rank), .id, .resource)) as $findings
| {
    schema_version: 1,
    generated_at: $now,
    domain: .domain,
    score: ([0, 100 - ([$findings[].severity | weight] | add // 0)] | max),
    counts: {
      critical: ([$findings[] | select(.severity == "critical")] | length),
      high: ([$findings[] | select(.severity == "high")] | length),
      medium: ([$findings[] | select(.severity == "medium")] | length),
      low: ([$findings[] | select(.severity == "low")] | length)
    },
    evaluated: {
      buckets: (.buckets | length),
      distributions: (.distributions | length),
      certificates: (.certificates | length),
      oidc_roles: (.oidc_roles | length),
      hosted_zones: (.hosted_zones | length),
      log_groups: (.log_groups | length),
      trivy: (.trivy != null)
    },
    findings: $findings
  }
