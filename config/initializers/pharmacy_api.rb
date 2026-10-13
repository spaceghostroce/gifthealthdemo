# Settings for talking to the (imaginary) pharmacy benefits manager API.
# Files in config/initializers/ run once when the app boots.
#
# The key comes from the environment, never from source. In a real deployment
# it is injected by the platform (a secrets manager, a CI variable, a .env file
# that is gitignored). The nil default lets the app boot in test and CI, where
# nothing talks to the PBM.
PHARMACY_API_URL = "https://api.example-pbm.test/v1"
PHARMACY_API_KEY = ENV.fetch("PHARMACY_API_KEY", nil)
