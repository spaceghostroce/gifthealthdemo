# gifthealthdemo
Demo gifthealth ci/cd pipeline for DevSecOps training

## About this repo

A hands-on DevSecOps learning project. A small Ruby on Rails pharmacy app that
started with **deliberately planted vulnerabilities**, plus a GitHub Actions pipeline
that gained one security layer per pull request and then caught, gated and finally
fixed every flaw.

- The plan and working rules: [`CLAUDE.md`](CLAUDE.md)
- Plain-English notes for each step: [`docs/`](docs/), ending with the
  coverage matrix and interview notes in [`docs/step-08.md`](docs/step-08.md)
- The planted flaws were marked `VULN:` in the source until step 8 removed them.
  To see them, check out any commit before PR #25, or read the step notes.

The pipeline, in order: Gitleaks, Brakeman + CodeQL, bundler-audit + Dependabot,
Checkov, OWASP ZAP (baseline on every PR, active scan weekly). All but the active
scan are required checks on `main`.

**Still a demo.** The Terraform is never applied and the app has no
authentication. Don't deploy it anywhere real.

### Run locally

```
bundle install
bin/rails db:prepare db:seed
bin/rails server
```
