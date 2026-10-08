# Step 2: Secret scanning with Gitleaks

## What a secret scanner does

It reads text (your files, and every past commit) looking for strings that are
shaped like credentials. Two kinds of rules:

- **Provider patterns**: an AWS access key always starts with `AKIA` and is 20
  characters; a Stripe live key starts with `sk_live_`; a GitHub token starts
  with `ghp_`. These are precise, so almost no false positives.
- **Generic patterns**: a word like `key`, `secret`, `token`, or `password`,
  then `=` or `:`, then a long random-looking string. "Random-looking" is
  measured as *entropy*. These catch home-grown secrets but can false-positive
  on things like hashes or example values.

## What we added

`.github/workflows/secret-scan.yml`: a second workflow that

1. checks out the **full** git history (`fetch-depth: 0`),
2. installs a pinned version of Gitleaks,
3. runs `gitleaks git` across every commit.

If Gitleaks finds anything it exits with code 1, which fails the job and turns
the PR check red. We did not add a way to bypass that on purpose. For secrets,
"red until fixed" is the right default.

## What it found

| Finding | File | Rule |
|---|---|---|
| `PHARMACY_API_KEY = "..."` | `config/initializers/pharmacy_api.rb` | `generic-api-key` |
| `ENV PHARMACY_API_KEY=...` | `infra/Dockerfile` | `generic-api-key` |

Both are the same fake key, found by the generic rule: the word `KEY`, an
equals sign, and a 36-character high-entropy string.

## What it missed, and why that matters

The Terraform file has `password = "Sup3rS3cretDbPassw0rd!"` and Gitleaks did
**not** flag it. The value is built from dictionary words with a few letter
swaps, so its entropy is below the generic rule's threshold. A human reads it
as obviously a password. A pattern matcher does not.

Lessons:

- Scanners are a floor, not a ceiling. They catch the common shapes cheaply
  and at scale. They do not replace code review for secrets.
- You can teach Gitleaks new shapes with a custom rules file (`.gitleaks.toml`).
  We may do that in step 5 when we tune the gates.
- Real-world fix is the same either way: move the value to an environment
  variable or a secrets manager, and rotate it, because history still has it.

## Gitleaks vs GitHub's built-in push protection

| | GitHub push protection | Gitleaks (this workflow) |
|---|---|---|
| When it runs | At push time, blocks the push | In CI, after the push, fails the check |
| What it knows | ~200+ provider patterns from partner companies | Provider patterns **plus** generic high-entropy rules |
| Our fake key | Let it through (generic format) | Caught it |
| Cost | Free on public repos, included in GitHub Advanced Security on private | Free, open source |

They complement each other. Push protection stops the most dangerous, most
recognizable leaks before they land. Gitleaks catches the long tail.

## Reading the Actions output

Open the PR, click the **Checks** tab, click **Secret Scan**, expand
**Scan git history for secrets**. Each finding shows the rule, file, line,
and commit hash. The secret itself is shown as `REDACTED` because of the
`--redact` flag. Never log real secrets, even in a failing build.
