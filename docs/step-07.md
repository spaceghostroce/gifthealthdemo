# Step 7: Dynamic testing with OWASP ZAP

## The problem this step covers

Every scanner so far read files. Brakeman read the Ruby, CodeQL read the
Ruby, Checkov read the Terraform, Gitleaks read the git history. None of them
ever sent a request to the running app. Dynamic Application Security Testing
(DAST) does exactly that: start the app, point a scanner at it from the
outside, and see what an attacker with a browser would see.

That viewpoint catches a different class of problem. A missing security
header is not in any source file; it is the absence of a line, and only the
HTTP response shows it. A debug page that leaks file paths only exists when
the server is running in the wrong mode. And a SQL injection that static
analysis flagged as "probably" becomes "confirmed" when a single quote
produces a 500.

## What ZAP is

OWASP ZAP (Zed Attack Proxy) is a free web scanner. It has two modes that
matter here, and they are different enough to deserve separate workflows.

**Baseline scan** (`.github/workflows/zap-baseline.yml`, runs on every PR).
ZAP crawls the site for a minute and only *looks*: response headers, cookies,
HTML comments, anything suspicious in what a normal visitor would receive. It
never sends an attack payload. Safe to run on every pull request because it
cannot break anything and finishes quickly.

**Active scan** (`.github/workflows/zap-full-scan.yml`, manual button plus a
weekly Sunday schedule). ZAP crawls, then attacks every parameter it found:
SQL injection strings, script tags, path traversal, command injection, about
130 rules. This is real attack traffic. It is slower, it can fill a database
with junk, and on a shared environment it can trip alarms, so it is not wired
to every PR.

Both workflows do the same setup: check out, install Ruby, prepare a SQLite
database, start the app on port 3000, wait for `/up` to answer, then run ZAP
with `--network=host` so the scanner container can reach `localhost`. The
report is appended to the run's summary page and uploaded as an artifact.
`fail_action: false` keeps both in report mode; neither blocks a merge yet.

## Baseline findings

| Finding | Risk | Real? |
|---|---|---|
| Content Security Policy header not set | Medium | Yes. Step 8. |
| Permissions-Policy header not set | Low | Yes. Step 8. |
| X-Content-Type-Options missing on 2 static files | Low | Yes. Step 8. |
| User-controllable HTML attribute on `/patients?q=` | Info | Lead, not a finding. Rails escapes it, so the reflected XSS attempt later passed. |
| Suspicious comments revealing `/home/runner/.../config/routes.rb` | Info | **Yes, and the most interesting one.** See below. |

## The finding that changed the workflow

The first baseline run reported "suspicious comments" containing the full
path to `config/routes.rb` on the CI runner. ZAP had requested a URL that
doesn't exist, and instead of a plain 404 it got the Rails *development*
error page: every route in the app, the file that defines them, and the
server's directory layout.

That page is a feature in development and a leak in production. The app was
running in development mode because that is Rails' default when nobody says
otherwise. Nobody had said otherwise.

The fix was to run the DAST jobs with `RAILS_ENV=production`, which required
three small things:

- A `SECRET_KEY_BASE` value, because production refuses to boot without one.
  The workflow sets a dummy string and says so in a comment: it signs cookies
  on a runner that is destroyed minutes later, so it is not a secret.
- Turning off `force_ssl`, because production redirects every plain-HTTP
  request to HTTPS and ZAP would scan nothing but 301s. The DAST jobs set
  `DAST_PLAIN_HTTP=1` and `config/environments/production.rb` checks for it.
  Real deployments never set the flag; TLS terminates at the load balancer.
- Nothing else. There is no asset pipeline to precompile.

Second baseline run: the routes leak was gone, the URL count dropped from 29
to 20 because the error page was no longer advertising every route to the
crawler, and the app booted in 2 seconds.

The principle: **scan what ships.** Scanning a dev-mode app finds dev-mode
problems and hides production ones. The security headers we set in step 8
will be production config too, and a dev-mode scan would never see them.

## The timeout, and why production mode fixed it too

The first active scan was killed by its 45-minute cap with no report. Two
causes, both dev-mode: Rails reloads code on every request, and every
non-existent URL (ZAP tries thousands) rendered that heavy error page instead
of a 1.7 KB 404. Locally, a bad URL took 8 ms in production and hundreds in
development.

Production mode alone would likely have been enough, but a scan that can
produce no output is worse than one that stops early, so the active workflow
also caps ZAP: stop attacking at 25 minutes and report what you have, no
single rule over 3 minutes, 5 parallel requests to match Puma's 5 threads.
The rerun finished in about 5 minutes.

## Active scan findings

| Finding | Risk | Verdict |
|---|---|---|
| SQL Injection on `/patients?q=` | High | **True positive.** A lone `'` returned a 500. This is the planted flaw. |
| CSP, Permissions-Policy, Cross-Origin-*, nosniff | Medium/Low | Real, same as baseline. Step 8. |
| Backup File Disclosure, 36 hits | Medium | **False positive.** `/patients.bak` returns 200 with the same HTML as `/patients`. Rails ignores an unknown extension and serves the normal page. ZAP compared status codes, never content. |
| Source Code Disclosure via `q=patients` | High | **False positive.** Searching for the word "patients" returned different results than a random string, scored 72% similar against a 75% threshold. That is a search box working. |
| HTTP Only Site | Medium | Artifact of our `DAST_PLAIN_HTTP` setup. |

## What active scanning missed

**The stored XSS in prescription notes.** All four XSS rules passed. The
reflected rule passed correctly because Rails escapes the search value.
The stored one is a real flaw that ZAP never reached: it would have to
submit the new-prescription form with a payload and then revisit the show
page, and the report shows no POST to `/prescriptions`. Brakeman found it
from the source in step 3 in about a second.

**Mass assignment, the hardcoded secret, CSRF turned off.** None are visible
from outside. Brakeman, Gitleaks and CodeQL each caught at least one.

This is the clearest argument in the project for running both kinds of
scanner. SAST sees every line but cannot prove exploitability. DAST proves
exploitability but only for what it can reach.

## Passive versus active, side by side

| | Baseline | Active |
|---|---|---|
| Runtime | about 1 min | about 5 min, capped at 25 |
| Trigger | every PR | manual button, weekly schedule |
| Found SQLi | no | yes |
| Found stored XSS | no | no |
| False positives | 0 | 2 rules, 37 alerts |
| Could break the app | no | yes |

One more lesson from the active run: the real finding was one line in a
report with 37 noisy ones. A scanner that nobody triages is a scanner that
buries its own results. The triage above took ten minutes with the app
running locally. That is the job.

## Interview framing

- DAST is the only layer that tests the app the way an attacker meets it.
  In a healthcare context the development error page is the concrete risk:
  file paths and route lists are reconnaissance for the next attack, and the
  app at that point had PHI in its tables.
- "Scan what ships" is a configuration question before it is a tooling
  question. The first run tested the wrong thing and nobody would have known
  without reading the findings.
- Baseline on every PR, active on a schedule, and never let an active scan
  loose on an environment you don't own.
- A High finding is a claim, not a fact. Two of the three Highs here were
  false. Reproduce before you escalate.

## Gotchas we hit

- The **Run workflow** button only appears once the workflow file is on
  `main`. On a feature branch, the sidebar entry is missing entirely.
- Clicking **Run workflow** sometimes lands on a GitHub 404 page. The run
  starts anyway; go back and refresh.
- `bin/rails assets:precompile` fails on this app because there is no asset
  pipeline. Production mode does not need it here.
- `force_ssl = true` turns a production-mode scan into a wall of 301s. The
  env-flag override is the cleanest way to keep it on everywhere else.
- Dev-mode 404 pages are heavy enough to time out a scanner by themselves.
