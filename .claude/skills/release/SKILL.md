---
name: release
description: Measure what the next Mecha Fighter release will hold (the PRs merged since the last vX.Y.Z tag), classify them, and recommend a version bump, defaulting to patch; label a PR release:minor or release:major before it merges when it needs more. Use when asked what is unreleased, what version is next, how to release or deploy, or whether a PR needs a bigger bump. Never dispatches a workflow.
---

# Release

Releases are automatic and Production is one human button (#31, `docs/RELEASING.md`):

- `release.yml` tags **every** main commit whose `ci` push run is green with the next patch version and publishes a GitHub Release (notes from the merged PRs, the site and game bundles, `manifest.json`, `SHA256SUMS`).
- `deploy.yml` is the only way Production changes. A human presses Actions, **deploy**, Run workflow. You never press it, and you never create tags or releases.

Your job is to measure and to recommend. Every number you report comes from `scripts/release/recommend`.

## Steps

1. **Measure.** Run `git fetch --tags origin`, then `scripts/release/recommend`. It makes one `gh` call (the PRs merged into main since the newest `vX.Y.Z` tag), drops any PR the tag already contains, and prints JSON (`schemas/release-recommendation.schema.json`). Done when you have that JSON.

2. **Classify.** Each entry of `pull_requests` carries `bump` and `reason`: `release:major` or `release:minor` labels raise it, and anything else is `patch`, the owner's default. Read every PR title. If one changes something a player or a link depends on, flag it: a removed URL, an incompatible save or Scoreboard format, or a new control scheme. Done when every PR has a bump you agree with, or a stated disagreement.

3. **Label before merge, never after.** A bump bigger than patch only counts if the label is on the PR when `release.yml` runs, which is right after its `ci` goes green on main. For an open PR that needs it, run `gh pr edit <n> --add-label release:minor` (or `release:major`) and say why in a PR comment. A PR that is already merged has already been released as a patch, so don't relabel it; report it instead. Done when every open PR you were asked about has the label it needs.

4. **Report.** Reply with `last_release`, `recommendation.next_version`, `recommendation.bump`, `recommendation.reason`, and one line per PR (number, title, bump). When `recommendation.release` is false, say there is nothing unreleased. Close with `how_to_release`, verbatim. Done when the reply holds those fields and nothing invented.

## Gotchas

- A release is not a deploy. Production serves whatever a human last deployed, so `version.json` on mechafighter.com can trail the newest tag. That is normal.
- Rolling back is also the human's Deploy button, with `version: previous` or `exact_version`. Recommend it, with the version, and never run it.
- Without the Godot export target (#17), releases carry no game bundle: the manifest's `skipped` says so. That is expected, not a failure.
- `release.yml` reads labels with its read-only token. If it cannot, it releases a patch and the notes say the labels were not counted.
