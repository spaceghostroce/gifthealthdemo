# Step 4: Dependencies with Dependabot and bundler-audit

## The problem this step covers

The app is a few hundred lines we wrote on top of about 80 gems other people
wrote. Most real breaches of a Rails app come through that second pile. A
dependency with a published CVE is a known, scriptable way in, and attackers
scan for exactly those versions.

## Two tools, two jobs

| | bundler-audit | Dependabot |
|---|---|---|
| What it is | A gem that runs in CI | A GitHub service |
| What it reads | `Gemfile.lock` | `Gemfile.lock` and workflow files |
| What it does | Prints every advisory matching a pinned version | **Alerts**: flags CVEs and opens a fix PR. **Version updates**: opens scheduled bump PRs for everything |
| Turned on by | Adding the gem + `.github/workflows/bundler-audit.yml` | Alerts: repo Settings. Version updates: `.github/dependabot.yml` |
| Why both | Visible on every PR next to the other scanners, works anywhere | Does the fixing, not just the finding |

## What they found

Dependabot opened 38 alerts the moment it was enabled (2 critical, 5 high,
14 medium, 17 low) and bundler-audit reported the same set in CI:

| Gem | Version | Advisories | Planted? |
|---|---|---|---|
| nokogiri | 1.14.0 | 18 | Yes (flaw 6) |
| puma | 6.4.0 | 4 | Yes (flaw 6) |
| actionview, activestorage, activesupport, rails-html-sanitizer | 7.1.6 | 16 | No. Rails 7.1 is end-of-life, so these will never be patched in 7.1 |

The Rails ones are Brakeman's end-of-life warning from step 3, now with CVE
numbers attached. Every advisory's "solution" field says upgrade to 7.2 or 8.x.
End-of-life means the only fix is the big one.

## The Dependabot PRs, and how to read one

Dependabot also opened five version-update PRs within minutes. Each one bumps
exactly one dependency and runs the full pipeline, so you get a CI verdict per
change. That's the whole value: you never have to wonder "will this update
break something?" because the answer is already in the checks.

| PR | Bump | Tests | Decision | Why |
|---|---|---|---|---|
| #5 | actions/checkout 4 to 7 | pass | Merge | Pipeline-only change, green |
| #6 | nokogiri 1.14.0 to 1.19.4 | pass | Merge | Fixes 18 advisories, green |
| #8 | puma 6.4.0 to 8.0.2 | pass | Merge | Fixes 4 advisories, green. Major version, but tests cover boot |
| #7 | minitest 5.27 to 6.0.6 | **fail** | Close, add ignore rule | minitest 6 is incompatible with Rails 7.1's test runner. CI caught it. |
| #9 | rails 7.1.6 to 8.1.4 | pass | Hold until step 5 | Fixes 16 advisories and the EOL finding. Held on purpose so the step 5 gate has something real to block, then merged as the fix |

The one that fails is the most instructive. Without CI, merging it would have
broken every test run. With CI, it cost nothing: read the red check, close the
PR, tell Dependabot to stop proposing it.

Telling Dependabot to skip something goes in `.github/dependabot.yml`:

```yaml
    ignore:
      - dependency-name: "minitest"
        versions: [ ">= 6" ]
```

Every ignore rule should have a comment saying why and when to revisit.
Ignore rules without reasons are how a repo ends up pinned to 2019.

## Report mode, again

The audit step uses `continue-on-error: true`. In the job view the step gets a
warning icon and the log ends with `exit code 1`, but the job and the PR check
stay green. The yellow lives inside the job page, not on the PR's check list.
Step 5 removes that line so the exit code fails the PR.

## Gotchas we hit

- A workflow file saved empty still gets picked up by GitHub, shows up in the
  Actions list under its file path (no `name:` to read), and fails as invalid.
  After pasting into a new file in VS Code, check the tab for the unsaved dot
  and run `git diff --stat` before committing.
- Updating the Gemfile without updating `Gemfile.lock` fails CI, because the
  runner installs gems in strict mode. `bundle install` regenerates the lock.
- `git mv` from Windows dropped the executable bit on `bin/` scripts again.
  `git update-index --chmod=+x` puts it back.
