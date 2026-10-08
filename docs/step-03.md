# Step 3: Static analysis (SAST) with Brakeman and CodeQL

## What static analysis is

**SAST** = Static Application Security Testing. The tool reads the source code
and reasons about it without running the app. Think of it as an automated code
reviewer that never gets tired and knows a long list of dangerous patterns.

Contrast with **DAST** (step 7, OWASP ZAP), which runs the app and attacks it
from the outside like a user would.

## Why two tools

| | Brakeman | CodeQL |
|---|---|---|
| Made by | Open source, Rails community | GitHub |
| Scope | Rails only | Many languages, plus GitHub Actions workflows |
| How it thinks | Pattern-matches Rails idioms it knows are risky | Builds a database of the code and traces data flow from user input to dangerous sinks |
| Speed | Seconds | Minutes |
| Results go | Log + GitHub Security tab (via SARIF) | GitHub Security tab |

Overlap is fine. Each one's blind spots are the reason to run the other.

## What Brakeman found (from the local preview run)

| Confidence | Category | File | Planted? |
|---|---|---|---|
| High | SQL Injection | `app/controllers/patients_controller.rb:14` | Yes (flaw 1) |
| High | Cross-Site Scripting | `app/views/prescriptions/_prescription.html.erb:24` | Yes (flaw 2) |
| Medium | Mass Assignment (`permit!`) | `app/controllers/patients_controller.rb:71` | Yes (flaw 4) |
| High | Unmaintained Dependency: Ruby 3.2.3 end-of-life 2026-03-31 | `.ruby-version` | **No. Real finding.** |
| High | Unmaintained Dependency: Rails 7.1 end-of-life 2025-10-01 | `Gemfile.lock` | **No. Real finding.** |

Two findings were not planted. The Ruby and Rails versions we picked for
convenience (what apt ships, what Ruby 3.2 supports) are both past end-of-life,
meaning no more security patches. That's a genuine supply-chain risk and we'll
deal with it in the dependency step. This is what good tooling does: it tells
you about the problems you didn't know you had.

**What Brakeman missed:** flaw 5, `skip_forgery_protection` in
`prescriptions_controller.rb`. Brakeman checks whether CSRF protection is
configured globally but didn't flag this per-controller opt-out. Watch whether
CodeQL catches it.

## Reading the results

Two places:

1. **The Actions log.** PR, Checks tab, Brakeman, expand "Show the report in the
   log". Each warning has a confidence level (High / Medium / Weak), a category,
   the file and line, and the offending code snippet.
2. **The Security tab.** Repo, Security, Code scanning. Both tools upload here
   in a common format called **SARIF**. Each alert links to the exact line, has
   a severity, and can be dismissed as false positive / won't fix / used in tests.
   This is the triage inbox a security engineer lives in.

## Report mode vs gate mode

The Brakeman job uses `--no-exit-on-warn`, so it reports but doesn't fail the
PR. CodeQL likewise only uploads alerts by default. This is deliberate for a
first rollout: turning a scanner on as a hard gate before anyone has looked at
its output tends to produce a flood of red builds, a pile of blanket exceptions,
and a team that learns to ignore it. Step 5 is where we decide which severities
block and flip the switch.

Gitleaks (step 2) is the exception: a leaked secret is always a stop-the-line
event, so it has been a gate from day one.

## CodeQL results: zero on the PR, and why that's not a bug

On PR #3, CodeQL reported **0 results** for Ruby while Brakeman reported 5. The
job log shows why: `Successfully created diff range extension pack`. On a pull
request, CodeQL runs in **diff-informed** mode and only reports alerts located
in lines the PR changed. Our planted flaws live in files this PR didn't touch,
so they were filtered out. The idea is to keep PR reviews focused on what the
author introduced rather than drowning them in pre-existing debt.

The full, un-filtered analysis runs on the `push` to `main` after the merge.
That's the run that populates the Security tab for the default branch.

Two scanners, three different answers to "is this code safe?":

| Scanner | On the PR | Why |
|---|---|---|
| Gitleaks | Red, 2 leaks | Scans all history, fails on anything |
| Brakeman | Green, 5 alerts uploaded | Whole-app scan, but report-only mode |
| CodeQL | Green, 0 alerts | Whole-app scan, but PR view is filtered to changed lines |

Knowing *why* each tool says what it says is the actual skill. A green check
is only reassuring if you know what it was and wasn't looking at.

## Housekeeping: pinning action versions

The first run warned that `github/codeql-action@v3` is deprecated in December
2026. We bumped both the CodeQL workflow and Brakeman's SARIF upload step to
`@v4`. Workflow actions are dependencies too, with the same upgrade hygiene as
gems.
