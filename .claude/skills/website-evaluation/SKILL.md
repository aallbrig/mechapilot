---
name: website-evaluation
description: Measured evaluation of one web page (a local build, the QA Environment or Production) with Lighthouse, axe-core, html-validate, lychee, response headers and TLS, scored against fixed thresholds into a ranked assessment. Use when asked to evaluate, audit or check the Marketing Site or Game Site.
---

# Website evaluation

Measure first, then judge. `scripts/website-eval/collect` runs the pinned tools against one page and `scripts/website-eval/score` turns their output into verdicts with the fixed thresholds in `scripts/website-eval/rules.jq`. Your assessment explains the report; every number and verdict you write comes from it.

## Steps

1. **Pick the target.** A local build is `build/site/production` after `task site:build`; the QA Environment is `https://aallbrig.github.io/mechapilot/`; Production is `https://mechafighter.com/` (or `https://game.mechafighter.com/`). A local build can't show the production edge, so its security headers and TLS score `not_applicable`: measure QA or Production when the question is about headers or certificates. Done when you have one directory or URL.

2. **Measure.** Run `task website:eval -- <target>`. Done when it prints `build/eval/website-<ts>.json`; the raw tool outputs sit beside it in `build/eval/website-<ts>/`. Exit 1 means a tool could not measure the page and nothing was scored: report the tool and its message, then stop. A Lighthouse `NO_FCP` error is itself the headline finding (the page paints nothing in a browser). Exit 3 means you are under `CI`, where only loopback targets run.

3. **Assess.** Write `build/eval/website-<ts>.md` from the report:
   - the target URL and kind, `verdict` and `counts` verbatim;
   - one table row per check in `dimensions` (dimension, check, value with unit, threshold, verdict);
   - then every entry of `fixes` in `rank` order, each with its evidence, the change that fixes it (site templates and CSS in `site/`, response headers and TLS in the CloudFront stack in `infra/`), and the re-run that proves the fix.

   Done when every `fixes` entry appears in rank order and each value in the file matches the report.

4. **Report back.** Reply with the verdict, the counts, the top three fixes and the path of the assessment. For each `fail` on QA or Production, first look for an open issue (`gh issue list --state open --search "<check id> in:title"`), comment the new evidence there on a match, and otherwise file one with `gh issue create --label needs-triage`, titled by the check id. Done when every `fail` on QA or Production is in an open issue.

## Gotchas

- Lighthouse runs once, with mobile emulation and simulated throttling, so lab Core Web Vitals move between runs. Before filing a warn or fail within 10% of its bound, re-run and quote both runs.
- The Marketing Site's CSP is a `<meta>` tag; only a response header can carry `frame-ancestors`, so those two checks measure the edge's response headers policy, never the page.
- `build/eval/` is gitignored and its reports carry local paths in `target.input`. Quote the URL, never the input path, in anything public.
- Thresholds change only in `scripts/website-eval/rules.jq`, together with `test_website_eval_scoring_thresholds` in `tests/shell/test_website_eval`, in a PR.
