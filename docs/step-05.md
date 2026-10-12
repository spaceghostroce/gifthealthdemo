# Step 5: Security gates and branch protection

## The problem this step covers

After step 4 the pipeline ran five scanners, and a PR with a critical SQL
injection would still merge with every check green. Only Gitleaks blocked.
Everything else was a report: visible if you went looking, ignorable if you
didn't. A report nobody is forced to read is decoration. This step turns the
reports into gates, and then locks the door so the gates can't be walked
around.

## Report mode vs gate mode

Each scanner had a different "don't fail" switch. Removing them is the whole
change:

| Scanner | Report-mode switch | Gate-mode change |
|---|---|---|
| Brakeman | `--no-exit-on-warn` | Removed. Added `-w2` so only medium and high confidence warnings fail the job. Exit code 3 = warnings found |
| bundler-audit | `continue-on-error: true` | Removed. Any advisory matching `Gemfile.lock` fails the job |
| Gitleaks | (none, already a gate) | Unchanged |
| CodeQL | (none, uploads to Security tab) | Unchanged. Its findings are gated through code-scanning alerts, not the job |

One extra fix came out of CodeQL's scan of our own pipeline: `ci.yml` had no
`permissions:` block, so its token defaulted to write access it never needed.
Added `contents: read`.

## What the gates caught on the first run

PR #15 flipped the switches and immediately went red three ways:

| Gate | Findings | Source |
|---|---|---|
| gitleaks | 2 | The planted API key, in the initializer and the Dockerfile |
| bundler-audit | 14 CVEs | All Rails 7.1.6 components. Nothing planted was left after step 4 |
| brakeman (`-w2`) | 5 warnings | 3 planted (SQLi, XSS, mass assignment) plus 2 real: Rails 7.1 and Ruby 3.2 both out of support |

## The gap that gate mode exposed

When Brakeman started failing, the two steps after it (print the report,
upload SARIF to the Security tab) were **skipped**. GitHub stops a job at the
first failed step. So the moment the gate fired, the findings vanished from
the log and never reached the Security tab. The one time you most need the
report is the one time you lose it.

Fix: `if: always()` on both follow-up steps. Report mode hid this for two
steps because the scan step never failed.

## What a permanently red gate forces you to decide

A gate that is red every day is a gate people learn to click past. Turning
gates on while the baseline is red means every existing finding needs a
decision, and only three decisions are legitimate:

1. **Fix it.** bundler-audit: merged Dependabot PR #9 (Rails 7.1.6 to 8.1.4).
   14 CVEs and the Rails end-of-life warning gone in one PR. Open Dependabot
   alerts went from 38 at the start of step 4 to 0.
2. **Defer it, with a date and an owner.** Brakeman: the three planted flaws
   have to survive until step 7's DAST scan has attacked them. Each one is
   listed in `config/brakeman.ignore` with a note that says DEFERRED, why, and
   when it gets fixed.
3. **Accept it, time-boxed.** Brakeman: Ruby 3.2.3 is past end of support but
   the dev machine is pinned to it. Accepted with a revisit date.

"It's noisy" is not on the list.

### How the ignore files work

Brakeman's ignore entries are keyed by **fingerprint**, a hash of the file,
the code, and the warning type. Change the line and the fingerprint changes,
so the warning comes back. You cannot accidentally ignore tomorrow's bug by
ignoring today's. The workflow also runs with `--ensure-ignore-notes`, which
fails the job if any entry lacks a note. Silent suppression is impossible.

Gitleaks fingerprints are `commit:file:rule:line`. That commit hash is the
uncomfortable part. Step 8 will remove the key from the code, and Gitleaks
will **still fail**, because the commit that introduced it is in history
forever and we scan all of history. Anyone who clones the repo can `git show`
that commit. A secret that has touched git is compromised the moment it
lands, and the only remediation is rotating it at the provider. Deleting it
from the code is cleanup. `.gitleaksignore` therefore records two things per
entry: the fingerprint, and the statement that the credential was rotated
(or, here, was never real).

## Branch protection: locking the door

Gates alone are advisory. PR #15 had three red checks and the Merge button
still worked. A **ruleset** on `main` (Settings, Rules, Rulesets) makes
GitHub refuse the merge:

- Pull request required. Nothing lands on `main` without going through the
  checks.
- Six required status checks: `test`, `gitleaks`, `brakeman`,
  `bundler-audit`, `analyze (ruby)`, `analyze (actions)`. Names must match
  the job names exactly.
- Force pushes and branch deletion blocked. Force-pushing is how history gets
  rewritten to hide a secret.
- **Empty bypass list.** Rulesets apply to admins unless told otherwise. The
  gate blocks the repo owner too. That is the honest configuration.

This writeup is the first PR to go through the locked door.

## Interview framing

Reports are for engineers who are already looking. Gates are for the Tuesday
afternoon when nobody is. For a healthcare app, the SQL injection the gate
blocks is a query against the patients table, and the key it blocks is the
one that talks to the pharmacy benefit manager. The exception process (fix,
defer with a date, accept with a date) is what separates "we have scanners"
from "we have a security program".

## Gotchas we hit

- The Dependabot `ignore:` block was pasted one line too early and landed
  inside the `labels:` list, which made `"dependencies"` an ignore rule.
  Dependabot validates the file on push and showed the error as a PR check.
- `.gitleaksignore` was created in `docs/` because that folder was highlighted
  in the VS Code sidebar. Gitleaks only reads it from the repo root. Click the
  empty space at the bottom of the file tree before creating a root-level file.
- A missing space (`--ensure-ignore-notes-o`) would have made Brakeman reject
  the whole command. Caught by reading the line back before committing.
- A new branch's first `git push` needs `--set-upstream`. Setting
  `git config --global push.autoSetupRemote true` once makes it automatic.
