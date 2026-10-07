# gifthealthdemo
Demo gifthealth ci/cd pipeline for DevSecOps training

## About this repo

A hands-on DevSecOps learning project. A small Ruby on Rails pharmacy app with
**deliberately planted vulnerabilities**, plus a GitHub Actions pipeline that gains one
security layer per pull request.

- The plan and working rules: [`CLAUDE.md`](CLAUDE.md)
- Plain-English notes for each step: [`docs/`](docs/)
- Find every planted flaw: search the code for `VULN:`

**Do not deploy this anywhere real.** The flaws are intentional.

### Run locally

```
bundle install
bin/rails db:prepare db:seed
bin/rails server
```
