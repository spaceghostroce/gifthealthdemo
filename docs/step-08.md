# Step 8: Fix everything, watch the pipeline go green, and reflect

## The problem this step covers

Seven steps built a pipeline that finds problems. This step closes the loop:
fix every planted flaw, confirm each scanner stops reporting it, and turn the
last report-mode scanners into gates. A security pipeline that only produces
findings is a dashboard. One that drives fixes and then blocks regressions is
a control.

The step took four pull requests, one per scanner family, so each merge
proved one thing:

| PR | What was fixed | Which scanner went green |
|---|---|---|
| 8a | SQL injection, mass assignment, stored XSS, CSRF opt-out, hardcoded key | Brakeman, CodeQL |
| 8b | Security headers on every response | ZAP baseline and active |
| 8c | Dockerfile and Terraform | Checkov, then added to required checks |
| 8d | This writeup, README | nothing to scan |

## The fixes, in plain English

**SQL injection** (`patients_controller.rb`). The search text was pasted
into the SQL string. Now it goes through a `?` placeholder, so the database
receives the query and the text separately and the text can never be read as
SQL. The ZAP active scan had proven the flaw with a single quote; after the
fix the same rule passes.

**Mass assignment** (same file). `permit!` accepted every form field the
browser sent, including `discount_tier`, which is a real column. It is now an
allow-list of four fields. Anything else is silently dropped.

**Stored XSS** (`_prescription.html.erb`). One word, `raw`, switched off
Rails' HTML escaping for the notes field. Deleting the word restores it.
Brakeman found this one; ZAP's active scan never reached it.

**CSRF opt-out** (`prescriptions_controller.rb`). `skip_forgery_protection`
turned off the hidden-token check for one controller. Deleting the line
restores the Rails default. CodeQL found this one; Brakeman did not.

**Hardcoded key** (`config/initializers/pharmacy_api.rb` and the Dockerfile).
Now read from the environment at run time. The old value is still in git
history and always will be, which is why the `.gitleaksignore` entries stay
and why in a real incident the key is rotated before the code is touched.

**Security headers** (three initializers). A strict Content Security Policy,
Permissions-Policy, the three Cross-Origin headers, and nosniff. Six inline
`style=""` attributes had to move into the stylesheet first, because a real
CSP forbids inline styles. That is the typical cost of CSP on an existing app.

**Dockerfile**. Pinned base image, dependency layer before code, no baked-in
key, unprivileged user, port 3000 only, a HEALTHCHECK on `/up`, and a
`Dockerfile.dockerignore` so `.git` and `.env` files never enter the image.

**Terraform**. Private bucket with a public-access block, versioning, KMS
encryption and access logging; SSH ingress deleted and egress narrowed to
HTTPS; database private, encrypted at rest and in transit, backed up, with
deletion protection, IAM auth, log exports and statement logging; password
moved to a `sensitive` variable. The file went from 78 lines to about 210,
mostly because one S3 bucket is five resources in the modern AWS provider.

## What each layer caught

The point of the project, in one table. Rows are the planted flaws plus the
real ones the tools found on their own. Columns are the layers in pipeline
order.

| Flaw | Gitleaks | Brakeman | CodeQL | bundler-audit / Dependabot | Checkov | ZAP baseline | ZAP active |
|---|---|---|---|---|---|---|---|
| SQL injection | | yes | yes | | | | **yes, proven** |
| Stored XSS | | yes | | | | | missed |
| Mass assignment | | yes | yes | | | | |
| CSRF opt-out | | missed | yes | | | | |
| Hardcoded API key (Ruby, Dockerfile) | yes | | | | | | |
| Hardcoded DB password (Terraform) | **missed** | | | | **missed** | | |
| Vulnerable gems (nokogiri, puma) | | | | yes | | | |
| Rails 7.1 / Ruby 3.2 end-of-life | | yes | | yes | | | |
| Dockerfile: latest, root, port 22, no healthcheck | | | | | yes | | |
| Dockerfile: COPY . . without ignore file | | | | | missed | | |
| Terraform: public bucket, public DB, no encryption, open SSH | | | | | yes | | |
| Missing security headers | | | | | | yes | yes |
| Dev-mode error page leaking paths | | | | | | **yes** | |

Three things to take from the table:

1. **No single tool covers even half the rows.** Brakeman and CodeQL each
   missed one flaw the other caught. ZAP proved the SQLi that SAST could only
   suspect, and missed the XSS that SAST found in a second.
2. **Two flaws beat every scanner.** The Terraform password looks like a
   password to a human and like a string to a regex. The unscoped `COPY . .`
   is only wrong in combination with a missing ignore file. Both were caught
   by reading the code. Code review is a layer.
3. **The best findings were the unplanted ones.** End-of-life Ruby and Rails,
   the development error page in CI, the `Feature-Policy` header name, error
   pages bypassing the header middleware. Nobody put those in on purpose.

## From report to gate: where the pipeline ended up

| Check | Mode | Blocks a merge when |
|---|---|---|
| test | gate | a test fails |
| gitleaks | gate | a secret pattern appears in the diff and isn't in `.gitleaksignore` |
| brakeman | gate | any medium-or-higher warning without an exception note |
| bundler-audit | gate | a gem in the lockfile has a published CVE |
| analyze (ruby), analyze (actions) | gate | the CodeQL job itself fails |
| checkov | gate, since 8c | any check listed under `hard-fail-on` fails |
| zap-baseline | gate, since 8c | the scan fails to run |
| zap active | scheduled | never; weekly report, read by a human |

Exceptions in force, every one with a reason in the file:

- `config/brakeman.ignore`: Ruby 3.2 end-of-life, accepted until 2026-12-01.
- `.gitleaksignore`: the demo key in two historical commits, permanent.
- `infra/main.tf`: five inline `#checkov:skip` lines. Three on the KMS key
  policy, where Checkov's generic IAM rules misread `Resource "*"`. Two on
  the log bucket, which cannot log to itself and which AWS will only deliver
  logs to with SSE-S3.
- `.checkov.yml`: nine skips, all cost or operational rather than security.

Open code-scanning alerts on `main`: zero. The six that corresponded to the
exceptions above were dismissed in the Security tab as "won't fix" with a
pointer to the reason in code, so the dashboard and the source agree.

## Gotchas we hit

- **Fixing a Brakeman finding does not remove its ignore entry.** The
  fingerprint just stops matching. Run Brakeman with an empty ignore file to
  see the true count, and prune stale entries so a regression can't hide
  behind them.
- **Rails 8.1's `permissions_policy` helper sends `Feature-Policy`**, the
  2020 header name. The config looked right; the wire was wrong. Header set
  directly instead.
- **Error pages and static files skip Rails' default headers.** A twelve-line
  Rack middleware at the top of the stack fixes all of them at once.
- **`base-uri`, `form-action` and `frame-ancestors` don't inherit from
  `default-src`.** ZAP flags a CSP that leaves them out, and it's right.
- **Hardening IaC creates new findings.** Adding a KMS key triggered a
  key-policy check, adding a parameter group triggered a force-SSL check, and
  the key policy triggered three IAM checks. Each round is a decision: fix,
  or skip with a reason.
- **Docker reads `.dockerignore` from the build context root**, not from
  next to the Dockerfile. The BuildKit alternative is a file named
  `Dockerfile.dockerignore` beside it.
- **Passive scanners can't see escaping.** ZAP's "user-controllable
  attribute" lead survives the XSS fix because it only sees that input is
  echoed, not that it's escaped. The active reflected-XSS rule is the real
  test, and it passes.

## Interview talking points

- **"Walk me through a DevSecOps pipeline."** Secrets first, because a leak
  is permanent. SAST next, two tools because each has blind spots.
  Dependencies, because most breaches come through a library. IaC, because a
  public bucket needs no bug. DAST last, because it needs a running app and
  proves what the others suspect. Then gates, with a written exception
  process, or it's all just a dashboard.
- **"How do you handle false positives?"** Reproduce first. Two of three
  High ZAP findings were false and I proved it with curl in ten minutes.
  Then the exception lives in code next to the thing it excuses, with a
  reason, an owner and a date where it's time-boxed. "It's noisy" is not a
  reason.
- **"How do you roll out a gate without blocking everyone?"** Report mode
  first, read the baseline, fix or except until it's green, then lock. Never
  lock a red baseline. Checkov ran red for two steps before it became a
  required check.
- **"What did scanners miss?"** The Terraform password, the Dockerfile copy
  scope, and the stored XSS from the outside. The answer to "which tool
  should we buy" is usually "the second one, and a reviewer".
- **"Why does this matter for a pharmacy?"** Every planted flaw maps to PHI:
  SQLi reads the patient table, the public bucket serves prescription PDFs,
  the dev error page lists every route to an attacker, the unencrypted
  database fails HIPAA 164.312 outright. The pipeline is the evidence that
  the controls exist and run on every change.
- **"What would you do next?"** Software bill of materials and image
  scanning on the built container; container signing; secret rotation
  tooling so a leak is a five-minute fix; and runtime monitoring, because
  the pipeline only sees what's in the repo.
