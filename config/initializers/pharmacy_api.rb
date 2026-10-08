# Settings for talking to the (imaginary) pharmacy benefits manager API.
# Files in config/initializers/ run once when the app boots.
#
# VULN: hardcoded secret.
# A real credential checked into git is visible to everyone with repo access,
# lives forever in history, and can't be rotated without a code change.
# Safe version: read it from the environment, e.g. ENV.fetch("PHARMACY_API_KEY")
# The value below is FAKE but shaped like a real key so scanners trigger.
PHARMACY_API_URL = "https://api.example-pbm.test/v1"
PHARMACY_API_KEY = "pbm_live_9X7mQ2vL4pR8sT1wZ6bN3cH5kJ0dF2gA"
