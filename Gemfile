# Gemfile: the list of Ruby libraries ("gems") this app depends on.
# Bundler reads this file and locks exact versions into Gemfile.lock.
source "https://rubygems.org"

ruby "3.2.3"

# The web framework.
gem "rails", "~> 7.1.6"

# SQLite: a file-based database, perfect for a demo. No server to run.
gem "sqlite3", ">= 1.4"

# Puma: the web server that actually answers HTTP requests.
# VULN: pinned to 6.4.0 on purpose. This version has a known CVE
# (CVE-2024-21647, HTTP request smuggling) fixed in 6.4.2.
# bundler-audit and Dependabot should both flag this in a later step.
gem "puma", "6.4.0"

# Nokogiri: HTML/XML parsing, used by Rails for sanitizing HTML.
# VULN: pinned to 1.14.0 on purpose. Later 1.14.x releases fixed several
# libxml2 CVEs. Another supply-chain finding for the dependency scanners.
gem "nokogiri", "1.14.0"

# Time zone data for Windows/JRuby; harmless no-op on Linux.
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  # Interactive debugger.
  gem "debug", platforms: %i[ mri windows ]

  # Brakeman: static security scanner built specifically for Rails (step 3).
  # require: false means it is a command-line tool, not loaded into the app.
  gem "brakeman", require: false
  # bundler-audit: checks Gemfile.lock against the Ruby advisory database (step 4).
  gem "bundler-audit", require: false
end

group :test do
  # Rails 7.1's test runner is not compatible with minitest 6 (released Sept 2026).
  # Not a planted flaw, just a version pin so the tests run.
  gem "minitest", "~> 5.0"
end
