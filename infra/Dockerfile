# Container image for the demo app.
# Build from the repo root:  docker build -f infra/Dockerfile -t gifthealth-demo .
#
# Hardened in step 8c. Of the six problems the original had, Checkov (step 6)
# found four, Gitleaks (step 2) found the baked-in key, and "COPY . ." without
# a .dockerignore is the one only a human reviewer caught. Each fix is marked.

# Pinned base image. "latest" can change under you between builds; a version
# tag means the same build today and next year.                 (CKV_DOCKER_7)
FROM ruby:3.2.3-slim

WORKDIR /app

# System packages first, so this layer is cached across code changes.
# curl is for the HEALTHCHECK below.
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential libsqlite3-dev curl \
    && rm -rf /var/lib/apt/lists/*

# Copy only the dependency manifests and install gems before the app code,
# so a code change doesn't re-run bundle install.
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Now the app. infra/Dockerfile.dockerignore keeps .git, logs, tmp and .env files out.
COPY . .

# The API key is NOT baked into the image any more. Inject it at run time:
#     docker run -e PHARMACY_API_KEY=... gifthealth-demo
# A key in an ENV line is readable by anyone who can pull the image.

# Run as an unprivileged user. If the app is compromised, the attacker is
# not root inside the container.                                 (CKV_DOCKER_3)
RUN useradd --create-home --shell /usr/sbin/nologin app && chown -R app:app /app
USER app

# Only the web port. SSH has no place in an app container.      (CKV_DOCKER_1)
EXPOSE 3000

# Let the orchestrator tell "hung" from "running". Rails' /up endpoint
# exists for exactly this.                                       (CKV_DOCKER_2)
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD curl -sf http://localhost:3000/up || exit 1

CMD ["bin/rails", "server", "-b", "0.0.0.0"]
