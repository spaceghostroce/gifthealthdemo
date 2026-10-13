# Extra response headers on every page.
#
# Rails already sends X-Frame-Options, X-Content-Type-Options and
# X-XSS-Protection by default (see config.action_dispatch.default_headers).
# These three are newer "cross-origin isolation" headers that ZAP's active
# scan flagged as missing. They stop other sites from embedding or reading
# our responses, which matters for a page full of PHI.
#
#   Cross-Origin-Opener-Policy   : a page that opens us in a new window can't
#                                  keep a handle to our window object.
#   Cross-Origin-Resource-Policy : other origins can't load our responses as
#                                  images, scripts or frames.
#   Cross-Origin-Embedder-Policy : we promise to only embed resources that
#                                  opt in. We embed nothing cross-origin, so
#                                  this costs nothing.
#
# Found by: ZAP active scan (step 7), "Cross-Origin-* Header Missing", Low.
# Permissions-Policy says which device features pages here may use. A
# patient-records app has no reason to touch the camera, microphone or
# location, so they are off; () means "no origin at all".
# Found by: ZAP baseline + active scan, "Permissions Policy Header Not Set".
# (Why not Rails' permissions_policy helper? See permissions_policy.rb.)
Rails.application.config.action_dispatch.default_headers.merge!(
  "Permissions-Policy"           => "camera=(), microphone=(), geolocation=(), usb=(), payment=(), fullscreen=(self)",
  "Cross-Origin-Opener-Policy"   => "same-origin",
  "Cross-Origin-Resource-Policy" => "same-origin",
  "Cross-Origin-Embedder-Policy" => "require-corp"
)
