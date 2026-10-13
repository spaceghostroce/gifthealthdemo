# Permissions-Policy header: see config/initializers/security_headers.rb.
#
# Rails ships a config.permissions_policy helper for this, but as of Rails
# 8.1 it still writes the header under the OLD name, Feature-Policy, which
# browsers deprecated in 2020 and ZAP does not recognise. We found that by
# curling the running app: the config looked right, the wire was wrong.
# Until Rails renames it, the header is set directly in security_headers.rb.
