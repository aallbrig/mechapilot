# Threat models

Every attack class that an adversarial review has found in this repository, one file per sensitive area. Before you ask for review, red-team your change against the models for the areas it touches. Reviewers read these models too, so they don't rediscover known classes.

- [merge-gate.md](merge-gate.md): merge gate, acceptance evidence, review verdicts, verification guard
- [agent-loop.md](agent-loop.md): Supervisor, sandboxed session, allowlist, skill
- [godot-test-evidence.md](godot-test-evidence.md): GdUnit4 runner and `godot.xml` evidence
- [hooks-and-toolchain.md](hooks-and-toolchain.md): git hooks, pinned toolchain, dev environment
- [infra.md](infra.md): OpenTofu, scanners, deploy trust, AWS evaluation
- [site.md](site.md): Marketing Site measurement
- [asset-credits.md](asset-credits.md): the game's asset credits check and `godot/CREDITS.md`
- [release.md](release.md): automatic releases, the Deploy button, rollback, workflow trigger and permission checks

## Entry format

Each model holds exactly one table with these columns, which `scripts/checks/threat-models` (run by `task lint`) validates. No other line in a model, and no line in this README, may contain a pipe character, because GitHub would render it as another table.

- **ID**: the model's prefix plus two digits (`MG-07`). IDs are unique across all models and are never reused.
- **Attack class**: a short name for the class. Describe attacks by class: never include account IDs, ARNs, hostnames, emails or secrets.
- **Description**: one line.
- **Found**: the PR whose review found it, as `[#<n>](https://github.com/aallbrig/mechapilot/pull/<n>)`.
- **Status**:
  - `mitigated`: fixed on main.
  - `residual`: accepted. A residual never blocks a review.
  - `open`: known and tracked, but not fixed on main yet. Finding it again is not a new block, except on the PR that claims to fix it.
- **Mitigation**: what stops it, or for a residual, why it is accepted.
- **Proof**: for `mitigated`, the one `test:<name>` or `check:<name>` that fails if the mitigation goes away. It must be defined in tracked test source the runner discovers, or be a tracked, executable `scripts/checks/<name>` that a task reachable from `task ci` runs. For `residual` and `open`, the tracking issue `#<n>`.

Only rows in main's copy of docs/threat-models/ count as accepted or tracked. A row a PR adds, changes or removes is itself under review: downgrading or removing a row, or adding a `residual` or `open` row for a hole the PR introduces, is a finding. The check compares against `origin/main` (from the merge-base) and rejects a removed row, a lowered status (`mitigated` > `open` > `residual`) or a row born `residual`, unless a commit on the branch carries the trailer `threat-model-downgrade: <ID> <reason>`. Reviewers judge every such trailer.

A reproduced attack becomes a regression test and a row here in the same PR. When an `open` entry's fix merges, change its status to `mitigated` and its proof to the regression test. Changes under `docs/threat-models/` are verification changes, so they need two reviews.
