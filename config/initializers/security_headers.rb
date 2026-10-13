# Security headers on EVERY response, including the ones Rails itself doesn't
# decorate.
#
# Rails adds its default headers (X-Frame-Options, X-Content-Type-Options...)
# only to responses that go through a controller. Three kinds of response
# never reach a controller and so went out bare, which is exactly what ZAP
# flagged in step 8b's first scan:
#
#   - static files from public/   (the stylesheet, robots.txt)
#   - the 404 page for an unknown URL
#   - the 422 page for a form post with a bad CSRF token
#
# The fix is a small piece of Rack middleware inserted at position 0, the very
# top of the stack. Every response passes through it on the way out, and it
# adds any header that is still missing. "Still missing" matters: Rails' own
# CSP middleware builds a per-request policy for controller responses, and we
# don't want to overwrite that, only fill the gaps.
#
# Found by: ZAP baseline + active scan (step 7, step 8b).
class SecurityHeaders
  HEADERS = {
    # Which device features pages here may use. A patient-records app has no
    # reason to touch the camera, microphone or location. () = no origin.
    # Rails' permissions_policy helper is NOT used: as of Rails 8.1 it still
    # emits the deprecated header name Feature-Policy (checked on the wire).
    "Permissions-Policy" => "camera=(), microphone=(), geolocation=(), usb=(), payment=(), fullscreen=(self)",

    # Cross-origin isolation: other sites can't hold a handle to our window,
    # load our responses as resources, or be embedded by us without opting in.
    "Cross-Origin-Opener-Policy"   => "same-origin",
    "Cross-Origin-Resource-Policy" => "same-origin",
    "Cross-Origin-Embedder-Policy" => "require-corp",

    # Rails sets these on controller responses; repeat them for static/error.
    "X-Content-Type-Options" => "nosniff",
    "X-Frame-Options"        => "SAMEORIGIN",
    "Referrer-Policy"        => "strict-origin-when-cross-origin",

    # Fallback CSP for static files and error pages. Controller responses get
    # the richer policy from content_security_policy.rb instead. base-uri,
    # form-action and frame-ancestors do NOT inherit from default-src, so
    # they must be spelled out or ZAP (rightly) reports them as undefined.
    "Content-Security-Policy" => "default-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'"
  }.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    HEADERS.each do |name, value|
      headers[name] = value unless headers.key?(name) || headers.key?(name.downcase)
    end
    [status, headers, body]
  end
end

Rails.application.config.middleware.insert_before 0, SecurityHeaders
