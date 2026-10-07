# GiftHealth DevSecOps Demo — Project Instructions

## Purpose

Hands-on DevSecOps learning project for a GiftHealth interview. We build a small,
deliberately insecure Ruby on Rails app, then add security tooling to a GitHub Actions
pipeline one layer at a time. Each layer is its own feature branch and pull request so the
history reads like a tutorial.

Ross is a cybersecurity professional and a **beginner at Rails and CI/CD**. Every change
must be explained in plain English: what the tool is, what class of problem it catches,
and what the output means. Code must be readable and commented.

## Working Rules

- **One step at a time.** Finish a step, open its PR, then STOP and wait for Ross to
  review, merge, and say "continue" before starting the next step.
- **Feature branch + PR for every step.** Branch names: `step-NN-short-name`. Never push
  to `main` directly.
- **Explain each git command** before running it until Ross says otherwise.
- **Intentional vulnerabilities stay in until the step that fixes them.** The point is to
  watch each scanner catch them. Mark every planted flaw with a `# VULN:` comment so they
  are easy to find and easy to remove later.
- **No real secrets.** Planted "secrets" must be obviously fake (e.g. `FAKE_API_KEY_...`)
  but shaped like real ones so scanners trigger.
- Local toolchain: Ruby 3.2 via apt on WSL (Ubuntu 24.04), SQLite for the database.
  Gems install to the user gem dir (`gem install --user-install`), no sudo gem installs.

## The Plan

| Step | Branch | What we add | What it teaches |
|------|--------|-------------|-----------------|
| 1 | `step-01-plan-and-demo-app` | This plan + a tiny Rails app (patients + prescriptions) with planted flaws: SQL injection, XSS, hardcoded secret, mass assignment, outdated gem, insecure Dockerfile/Terraform snippet. Basic CI that runs tests. | What a Rails app looks like; what a pipeline is; the baseline before security. |
| 2 | `step-02-secret-scanning` | Gitleaks in CI + GitHub push protection notes. | Secrets in source code; why scanning must run before code lands. |
| 3 | `step-03-sast` | CodeQL (GitHub-native) + Brakeman (Rails-specific SAST). | Static analysis: finding SQLi/XSS without running the app. Two tools, two viewpoints. |
| 4 | `step-04-dependencies` | Dependabot config + bundler-audit in CI. | Supply chain: known-vulnerable gems (CVEs) and automated update PRs. |
| 5 | `step-05-security-gates` | Make scanners fail the build on high/critical findings; required status checks; branch protection on `main`. | Turning "reports" into "gates". Severity thresholds and false-positive handling. |
| 6 | `step-06-iac-checkov` | Checkov against the Dockerfile and Terraform. | Infrastructure as Code scanning: misconfigurations before deploy. |
| 7 | `step-07-dast-zap` | Build the app in CI, run OWASP ZAP baseline scan against it. | Dynamic testing: attacking the running app from the outside. |
| 8 | `step-08-fix-and-reflect` | Fix the planted flaws, watch the pipeline go green, write up what each layer caught. | The remediation loop and interview talking points. |

Steps may be split further if a PR gets too big to explain in one sitting.

## Repo Layout (after step 1)

- Repo root — the Rails demo app itself (`gifthealth_demo`): `app/`, `config/`, `db/`, `Gemfile`, etc.
- `.github/workflows/` — one workflow file per concern, named after the tool
- `infra/` — Dockerfile and a small Terraform file, both intentionally sloppy for Checkov
- `docs/` — plain-English notes written after each step (`docs/step-NN.md`)

## Interview Framing

GiftHealth is a pharmacy/healthcare company, so the demo app models patients and
prescriptions. When explaining a finding, connect it to HIPAA/PHI exposure where that is
honest and natural. Don't force it.
