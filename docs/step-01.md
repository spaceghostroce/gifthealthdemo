# Step 1: The demo app and its planted flaws

## What we built

A tiny Ruby on Rails app for a pharmacy. It has two kinds of records:

- **Patients** (name, date of birth, email, insurance ID, discount tier)
- **Prescriptions** (which patient, drug name, dosage, free-text notes)

You can list, search, create, edit, and delete both. That is the whole app.

### How a Rails app is laid out

| Folder / file | What lives there |
|---|---|
| `app/models/` | Ruby classes that represent database tables (`Patient`, `Prescription`). |
| `app/controllers/` | Code that handles each web request. One method per page/action. |
| `app/views/` | HTML templates (`.erb` = HTML with Ruby snippets in `<%= %>`). |
| `config/routes.rb` | Maps URLs to controller methods. |
| `config/initializers/` | Small setup files that run once at boot. |
| `db/migrate/` | Scripts that create or change database tables. |
| `db/seeds.rb` | Sample data. |
| `test/` | Automated tests. `bin/rails test` runs them. |
| `Gemfile` / `Gemfile.lock` | The list of libraries (gems) and their exact versions. |

## The planted vulnerabilities

Every one is marked with a `# VULN:` comment in the code. Search the repo for `VULN:` to find them all.

| # | Flaw | Where | Which later step should catch it |
|---|---|---|---|
| 1 | **SQL injection**: search text pasted into a SQL string | `app/controllers/patients_controller.rb` (`index`) | Step 3 (Brakeman, CodeQL), Step 7 (ZAP, maybe) |
| 2 | **Cross-site scripting (XSS)**: `raw` disables HTML escaping on notes | `app/views/prescriptions/_prescription.html.erb` | Step 3 (Brakeman, CodeQL) |
| 3 | **Hardcoded secret**: fake API key in source | `config/initializers/pharmacy_api.rb`, also `infra/Dockerfile` | Step 2 (Gitleaks) |
| 4 | **Mass assignment**: `permit!` lets the browser set any field | `app/controllers/patients_controller.rb` (`patient_params`) | Step 3 (Brakeman) |
| 5 | **CSRF protection disabled** | `app/controllers/prescriptions_controller.rb` | Step 3 (Brakeman) |
| 6 | **Known-vulnerable gems**: `puma 6.4.0`, `nokogiri 1.14.0` | `Gemfile` | Step 4 (bundler-audit, Dependabot) |
| 7 | **Insecure Dockerfile**: `latest` tag, root user, baked-in secret, port 22, no healthcheck | `infra/Dockerfile` | Step 6 (Checkov), Step 2 (Gitleaks for the secret) |
| 8 | **Insecure Terraform**: public S3 bucket, SSH open to the world, public unencrypted DB, hardcoded DB password | `infra/main.tf` | Step 6 (Checkov), Step 2 (Gitleaks for the password) |

### Seeing two of them work

With the app running locally (`bin/rails server`):

- **SQL injection**: searching for `Alice` returns 1 patient. Searching for
  `' OR 1=1) --` returns *every* patient. Searching for `zzz` alone returns none.
  The quote character broke out of the SQL string, `OR 1=1` made the condition
  always true, and `--` turned the rest of the query into a comment.
- **XSS**: Bob's prescription note contains `<b>...</b>`. Rails would normally
  display those characters literally. Because of `raw`, the browser renders them
  as real bold HTML. Swap `<b>` for `<script>` and you have code execution in
  every viewer's browser.

## The pipeline so far

`.github/workflows/ci.yml` is the baseline. On every pull request it:

1. checks out the code,
2. installs Ruby and the gems,
3. builds the test database,
4. runs `bin/rails test`.

That's "CI" (continuous integration): tests run automatically on a clean machine
so "works on my laptop" stops being the standard. Every security tool we add
from here is just another job in this same system.

## A note on GitHub's built-in secret scanning

This repo already has GitHub **push protection** turned on. It would have
rejected our push if the fake key looked like a known provider's format (for
example an AWS key starting with `AKIA`). Our planted key uses a generic format,
so GitHub let it through. That is exactly the gap Gitleaks closes in step 2:
GitHub knows ~200 provider patterns, Gitleaks also looks for generic
high-entropy strings next to words like `key`, `secret`, `password`.

## Running it yourself

```
bundle install
bin/rails db:prepare db:seed
bin/rails server
```

Then open http://localhost:3000.
