# Step 6: Infrastructure as Code scanning with Checkov

## The problem this step covers

Steps 3 through 5 scanned the application. This step scans the files that
describe where the application runs: the Dockerfile and the Terraform in
`infra/`. A misconfiguration there is a breach with zero bugs in the code. A
world-readable S3 bucket of prescription PDFs needs no SQL injection to leak
PHI, it just needs someone to guess the bucket name.

Scanning the infrastructure *description* before anything is deployed is the
whole point of IaC scanning. The Terraform in this repo is never applied, and
Checkov doesn't care. It reads the plan, not the cloud.

## What Checkov is

Checkov is a Python tool with roughly a thousand built-in policies. Each has
an ID you can look up, like `CKV_AWS_17` ("RDS is not publicly accessible")
or `CKV_DOCKER_3` ("a USER is set for the container"). It parses Terraform,
Dockerfiles, Kubernetes manifests, CloudFormation and more, then checks every
resource against every applicable policy and lists the ones that fail.

The workflow (`.github/workflows/checkov.yml`) differs from the Ruby ones in
three ways: it installs Python instead of Ruby, it pins Checkov to one version
for the same reason Gitleaks was pinned, and it uploads SARIF with
`if: always()` so the findings survive a red job.

## What it found

| File | Passed | Failed |
|---|---|---|
| infra/Dockerfile | 26 | 4 |
| infra/main.tf | 12 | 25 |

Every planted flaw was caught: `latest` tag, port 22, no HEALTHCHECK, no
USER, public-read bucket, SSH open to the world, public database, unencrypted
database, no backups, no deletion protection. Plus a long tail we didn't
plant: no Multi-AZ, no cross-region replication, no enhanced monitoring, no
event notifications, no lifecycle rules.

Two misses worth remembering. Checkov's Terraform and Dockerfile policies do
not look for hardcoded credentials, so the database password in `main.tf`
went unflagged. Gitleaks missed it too: its generic rule keys on words like
"api key" and "token", and the value sits on a line that just says
`password`. Two scanners, zero catches. Step 8 comes back to this.

## Twenty-nine findings are not twenty-nine blockers

This is the step where the tool stops being the point and the judgment starts.
A policy file, `.checkov.yml` at the repo root, sorts findings into three
buckets:

| Bucket | Config key | What it means | Count |
|---|---|---|---|
| Hard fail | `hard-fail-on` | Job goes red. PHI exposed or host trivially owned | 7 |
| Report only | (default, with `soft-fail: true`) | Visible in the log and Security tab, doesn't block. Backlog | 13 |
| Skip | `skip-check` | Not run. Each needs a written reason | 9 |

The hard-fail list is the security call: public bucket, no public-access
block, public database, unencrypted database, SSH from anywhere, port 22 in
the container, container as root. Each line carries the reason, and the RDS
encryption entry cites the HIPAA clause.

The skip list is the "does this apply to us" call: Multi-AZ and cross-region
replication are availability and cost decisions, event notifications and
performance insights are operations tooling, and port 80 open to the internet
is what a public web server is. Every skip has a reason on the line above
it, the same rule as `brakeman.ignore`.

Report-only is everything else: real hardening (backups, versioning, access
logs, KMS, the `latest` tag) that belongs in a backlog rather than in front of
a merge button.

The split between **workflow** and **policy** matters. The workflow says which
files to scan and where the output goes. The policy says what we consider a
breach. A different team can own each, and the policy is reviewable in a PR
like any other security decision.

## Where the findings show up, and why main looked empty

Code scanning alerts are attached to a branch. The Security tab defaults to
`branch:main`, and main had never run the Checkov job until PR #19 merged. On
the PR itself the 29 alerts were visible under Checks, Checkov, or on the
Security tab with the filter changed to `pr:19`. After the merge, main shows
20: the 9 skipped checks never ran.

GitHub doesn't know which 7 are hard-fail. That shows on the workflow run,
not in the alert list: a red Checkov job means a hard-fail check failed.

## Red on purpose

The Checkov job on main is red and will stay red until step 8 fixes the
infra. It is not a required check, so it blocks nothing. Same baseline rule
as step 5: a gate only gets locked once the baseline passes it, otherwise
every unrelated PR is red and people learn to click past. After step 8 the
job goes green and gets added to the ruleset.

## Interview framing

For a pharmacy, the infrastructure findings are the ones that map most
directly to HIPAA: encryption at rest (164.312(a)(2)(iv)), access controls on
the bucket holding prescriptions, audit logging. The three-bucket policy is
the answer to "how do you keep an IaC scanner from being noise": decide once,
in a reviewed file, what counts as a breach, and let the rest be backlog.

## Gotchas we hit

- Scanning with `-d infra` produced absolute file paths in the SARIF, which
  GitHub can't map to lines. Naming the files with `-f infra/Dockerfile -f
  infra/main.tf` from the repo root gives `infra/Dockerfile`, which works.
- Checkov's `--output-file-path console,checkov.sarif` is one argument: CLI
  output to the console, SARIF to that file. With a single `-o sarif` it
  instead treats the path as a directory.
- Severity-based gating (`--hard-fail-on HIGH`) needs the vendor's platform
  key. The open-source build has no severities, so the policy uses check IDs.
