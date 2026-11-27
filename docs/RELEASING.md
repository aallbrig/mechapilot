# Releasing and deploying

Building and releasing are automatic. Production changes only when you press **Deploy**. (#31)

## Deploy (the one button)

1. Open **Actions**, choose **deploy**, then **Run workflow**. Leave the branch on `main`.
2. Pick the version:
   - `latest` (the default) is the newest release.
   - `previous` is the release before it. Deploying it is a rollback.
   - `exact_version` overrides both, for example `v0.1.7`.
3. Press **Run workflow**.

The run summary shows what was live before, what is live now, every assertion, and the 10 most recent releases. You never need to open the Releases page.

### What a deploy does

1. **Pre-flight.** The deploy has no AWS credentials yet. If any of these checks fails, it stops and nothing changes:
   - The release exists and the release workflow published it.
   - The release is immutable, or every one of its assets was uploaded by the release workflow (`github-actions[bot]`). An asset that someone else uploaded or replaced later, for example with `gh release upload --clobber`, is refused. Each asset is downloaded by its asset id, so the checked bytes are the deployed bytes.
   - Its assets are exactly the files in `SHA256SUMS`, and every checksum matches.
   - `manifest.json` names that tag and the tag's commit, which is on main, and it records a green `ci` push run.
   - Every file in every bundle matches the manifest.
   - Production is healthy (`scripts/checks/prod-smoke`).
   - The version each site serves (`version.json`) is recorded. That release is verified the same way, as that site's own rollback target.
2. **Deploy.** The workflow assumes the OIDC deploy role. For each site in the release, it:
   - uploads the pre-gzipped `.wasm` and `.pck` with their `Content-Type` and `Content-Encoding: gzip`;
   - syncs the rest of the site with `--delete`;
   - writes `version.json`;
   - invalidates CloudFront and waits for the invalidation to finish.
3. **Post-deploy checks:**
   - `prod-smoke` passes;
   - `version.json` equals the target;
   - the game's pre-gzipped files answer 200 with the right type and encoding, and their bytes match the manifest's sha256.
4. **Automatic rollback.** If any post-deploy check fails, the deploy puts back the version that was live on each site (each site its own), the same way. It runs the checks again, and the run fails with a summary of both attempts. A run that ends `rollback-failed` needs you now.

### First deploy

A site that has never been deployed has no `version.json`, so it has no rollback target, and pre-flight refuses it. Tick **first_deploy** for the first deploy of each site: the first deploy of all, and the first release that includes the game. Sites that already have a `version.json` are still checked as usual.

## Releases (automatic, no button)

Each push to main whose `ci` run succeeds becomes a release (`release.yml`).

- `latest` and `previous` count only releases the release workflow published. A release someone published by hand is never deployed.
- The version is the highest `vX.Y.Z` tag with its patch bumped, or `v0.1.0` for the first release. Tags like `v1.2.3-rc`, `v01.2.3` or `vX` are ignored.
- Label a PR `release:minor` or `release:major` **before it merges** to bump more. The `release` skill recommends a bump.
- The assets are `marketing-site.tar.gz`, `game-web.tar.gz` (once the Godot export lands, #17), `manifest.json` and `SHA256SUMS`. Until then the manifest lists the game bundle under `skipped`, and the release notes say so.
- The notes list each merged PR with its title and linked issues.
- A ci run that finishes after a newer commit was already released is skipped, because that newer release contains it.

## Human steps (once)

Until these are done, a deploy fails at its first step with `not configured`, and changes nothing.

1. Apply the infrastructure (`infra/README.md`). The deploy role trusts only `ref:refs/heads/main:environment:production`.
2. In **Settings, Environments, production**, limit deployment branches to `main`.
3. Add these as variables of the `production` environment, from `tofu -chdir=infra/stacks/prod output`. They are never committed, and the deploy masks them in its log:
   - `PROD_DEPLOY_ROLE_ARN`
   - `PROD_MARKETING_BUCKET`
   - `PROD_MARKETING_DISTRIBUTION_ID`
   - `PROD_GAME_BUCKET`
   - `PROD_GAME_DISTRIBUTION_ID`
4. **Required:** turn on **immutable releases** in the repository settings. Then a published release's tag and assets can never be changed or moved. The deploy also refuses any release whose assets someone other than the release workflow uploaded, but immutability is what stops a Contents-write token (the Agent Loop's included) from rewriting or deleting a release in the first place.

## Who can deploy

Only someone with Actions write permission can press Deploy. These checks stop anything else from deploying:

- `check:production-dispatch-only` fails if a job in the `production` environment sits in a workflow with any trigger other than `workflow_dispatch`. It also fails if any workflow requests `actions: write`, since such a workflow could dispatch the deploy itself.
- `check:workflow-permissions` keeps `deploy.yml` at `id-token: write` and `contents: read`, and `release.yml` at `contents: write`. No other workflow may write contents, so only `release.yml` can publish a release as `github-actions[bot]`. The deploy's pre-flight requires that.
- The Agent Loop's token has no Actions or Workflows permission (its preflight attests this), so agents can't press the button.

There is no tag ruleset and no required reviewer, by the owner's choice. Anyone with write access to this repository can change what main deploys, but only through the merge gate. Replaced assets are refused by the deploy, and with immutable releases (step 4) they can't be replaced at all.
