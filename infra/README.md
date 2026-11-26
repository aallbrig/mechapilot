# infra

OpenTofu for mechafighter.com: the Marketing Site (apex, `www` redirects to it) and the Game Site (`game.`), each a private S3 bucket behind CloudFront, plus the GitHub Actions deploy role. Design decisions are on issues #6 (inventory) and #11 (layout).

**Applying is for humans only.** Agents and CI run the offline checks; they never plan or apply against AWS.

## Layout

| Path | What it is |
|---|---|
| `modules/static-site` | Private bucket (Block Public Access, BucketOwnerEnforced, SSE-KMS with a rotated customer-managed key, versioning, old versions expire), CloudFront with origin access control, HTTPS redirect, TLS 1.2 (2021 policy), HTTP/2 and HTTP/3, IPv6, compression, a security-headers policy (HSTS, CSP with `frame-ancestors 'none'`, nosniff, `X-Frame-Options: DENY`, referrer policy, Permissions-Policy), a viewer-request function (redirect hosts, directory index), 404 page, `A` and `AAAA` aliases, and optional access logs (CloudFront standard logging v2 into a private bucket, expired after 90 days). |
| `stacks/bootstrap` | The remote-state bucket (versioned, private, SSE-KMS, TLS only). Uses local state. |
| `stacks/prod` | Imports the existing hosted zone and wildcard certificate, creates a shared WAF (AWS common rules, known bad inputs, per-IP rate limit), both sites and the deploy role. Remote state, partial backend config. |

Everything is in us-east-1: CloudFront only takes certificates and CLOUDFRONT-scope WAF ACLs from there.

### Nothing account-specific is committed

Zone ID, certificate ARN, bucket names and the state bucket come from untracked files:

- `stacks/prod/prod.auto.tfvars` (copy `prod.auto.tfvars.example`)
- `stacks/prod/backend.hcl` (copy `backend.hcl.example`)
- `stacks/bootstrap/bootstrap.auto.tfvars` (copy `bootstrap.auto.tfvars.example`)

`infra/.gitignore` ignores them, and `scripts/checks/infra-no-identifiers` (in `task lint`) fails on account IDs, ARNs with an account, hosted-zone IDs, CloudFront IDs, access key IDs and email addresses anywhere under `infra/`. It never prints the match, so a finding can't leak into public CI logs.

## Checks (offline, in `task lint` and so in `task ci`)

| Task | Does |
|---|---|
| `task infra:validate` | `tofu fmt -check`, then `tofu init -backend=false -lockfile=readonly` and `tofu validate` in every module and stack |
| `task infra:lint` | `tflint` with the `terraform` "all" preset and the AWS ruleset |
| `task infra:scan` | `trivy config`, failing on any HIGH or CRITICAL finding. No ignore file is loaded: findings get fixed, not suppressed. |

OpenTofu, tflint, the tflint AWS ruleset and trivy are pinned in `.mise.toml` with checksums in `mise.lock`; tflint finds the ruleset through `TFLINT_PLUGIN_DIR` and never downloads plugins. Each `.terraform.lock.hcl` has provider hashes for linux_amd64, linux_arm64, darwin_amd64 and darwin_arm64. To upgrade the provider, run `tofu providers lock -platform=linux_amd64 -platform=linux_arm64 -platform=darwin_amd64 -platform=darwin_arm64` in each directory (after `tofu init -backend=false` in `stacks/prod`).

## Human runbook

Prerequisites: `task setup`, and AWS credentials for the account in your shell (never in the repo). `task infra:plan` and `task infra:apply` refuse to run in CI.

### 1. Bootstrap the state bucket (once)

```sh
cp infra/stacks/bootstrap/bootstrap.auto.tfvars.example infra/stacks/bootstrap/bootstrap.auto.tfvars   # fill in
task infra:plan -- bootstrap
task infra:apply -- bootstrap
```

Its local state (`terraform.tfstate`, gitignored) holds only the state bucket and key. Keep a copy somewhere private, or leave it: the bucket has `prevent_destroy` and can be re-imported.

### 2. Plan production

```sh
cp infra/stacks/prod/backend.hcl.example infra/stacks/prod/backend.hcl         # bucket and region from step 1's outputs
cp infra/stacks/prod/prod.auto.tfvars.example infra/stacks/prod/prod.auto.tfvars   # zone ID, cert ARN, two new bucket names
task infra:plan
```

Read the plan before applying:

- The hosted zone and certificate must show **import** with no changes. If the certificate shows a replacement, its domain or SANs differ from the config; fix the config (the `prevent_destroy` guard stops the plan anyway).
- `marketing_aliases_enabled = false` on the first apply, so the new Marketing Site distribution comes up without the apex and `www` names, which the 2022 distribution still holds (CloudFront refuses to put one name on two distributions).
- The Game Site gets its names and DNS straight away: `game.` has no record today.

### 3. Apply and deploy

```sh
task infra:apply
```

Then, in GitHub, without putting any value in the repo:

- Create (or confirm) the `production` environment and restrict its deployments to `v*` tags. The deploy role trusts only `repo:aallbrig/mechapilot:environment:production` and `repo:aallbrig/mechapilot:ref:refs/tags/v*`.
- Store `deploy_role_arn` and the bucket names and distribution IDs from `tofu -chdir=infra/stacks/prod output` as Actions variables for the deploy workflow (#31).

Deploys must upload `.wasm` as `application/wasm`, and pre-compressed files with a matching `Content-Encoding`, or the Godot loader breaks.

### 4. Cut over the Marketing Site (DNS switch)

1. Upload the Marketing Site build to the new bucket and check it on the new distribution's `*.cloudfront.net` name (output `marketing_site.distribution_domain_name`).
2. Move the names: either remove `mechafighter.com` and `www.mechafighter.com` from the 2022 distribution's alternate domain names (a few minutes of errors until step 3), or move them with no downtime with `aws cloudfront associate-alias` after adding the TXT record it asks for.
3. Set `marketing_aliases_enabled = true`, then `task infra:plan` and `task infra:apply`. The apex and `www` `A` records are overwritten to point at the new distribution, and `AAAA` records are added.
4. Check `https://mechafighter.com`, `https://www.mechafighter.com` (301 to the apex) and `https://game.mechafighter.com` over IPv4 and IPv6, and the response headers.

### 5. Retire the 2022 resources (separate, deliberate step)

After a few days of clean traffic: disable, then delete, the 2022 CloudFront distribution; empty and delete the two public site buckets and their three log buckets. They were never managed here, so this is done by hand. Keep the ACM DNS-validation CNAME in the zone: ACM needs it to renew the certificate.

## Costs to expect

Besides traffic: one WAF web ACL with three rules (about $8 a month plus per-request fees), three KMS keys ($1 a month each), and log storage for at most 90 days.
