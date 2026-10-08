# Container image for the demo app.
# Intentionally sloppy so Checkov (step 6) has something to find.
# Build from the repo root:  docker build -f infra/Dockerfile -t gifthealth-demo .

# VULN: floating "latest" tag. The image can change under you between builds.
FROM ruby:latest

WORKDIR /app

# VULN: copies the entire repo, including .git and any local secrets, into the image.
COPY . .

# VULN: secret baked into the image. Anyone who can pull the image can read it.
ENV PHARMACY_API_KEY=pbm_live_9X7mQ2vL4pR8sT1wZ6bN3cH5kJ0dF2gA

RUN apt-get update && apt-get install -y libsqlite3-dev && bundle install

# VULN: port 22 exposed. A web app has no business running SSH.
EXPOSE 3000 22

# VULN: no USER instruction, so the app runs as root inside the container.
# VULN: no HEALTHCHECK, so the orchestrator can't tell if the app is hung.
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
