# Content Security Policy (CSP).
#
# The browser enforces this header: it only loads scripts, styles, images and
# so on from the places listed here. Even if an attacker gets HTML into a page
# (an XSS bug like the one fixed in step 8a), the browser refuses to run a
# script that isn't from our own origin. CSP is the safety net under output
# escaping, not a replacement for it.
#
# This app has no JavaScript and one stylesheet served from /stylesheets, so
# the policy is strict: everything from our own origin only, no inline styles
# or scripts, no plugins, and nobody may put us in an iframe.
#
# Found by: ZAP baseline + active scan (step 7), "CSP Header Not Set", Medium.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self                # fallback for anything not listed
    policy.script_src  :self                # no inline <script>, no third parties
    policy.style_src   :self                # no inline style="", stylesheet only
    policy.img_src     :self, :data         # :data allows tiny inline icons
    policy.font_src    :self
    policy.object_src  :none                # no Flash/Java-style plugins
    policy.base_uri    :self                # stops <base href> hijacking links
    policy.form_action :self                # forms may only post back to us
    policy.frame_ancestors :none            # clickjacking: nobody can frame us
  end

  # Enforce, don't just report. Flip this to true while rolling CSP out on a
  # live app: violations go to the browser console instead of being blocked.
  config.content_security_policy_report_only = false
end
