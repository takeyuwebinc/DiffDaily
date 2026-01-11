# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, "*"
    policy.object_src  :none
    policy.script_src  :self, :https, "https://cdn.jsdelivr.net", "https://www.googletagmanager.com", :unsafe_inline
    # Mermaidが動的にSVGのインラインスタイルを生成するため、unsafe-inlineを許可
    policy.style_src   :self, :https, "https://cdn.jsdelivr.net", :unsafe_inline
    # Google Analytics用
    policy.connect_src :self, "https://www.google-analytics.com", "https://analytics.google.com", "https://region1.google-analytics.com"
    # Specify URI for violation reports
    # policy.report_uri "/csp-violation-report-endpoint"
  end

  # Generate session nonces for permitted importmap and inline scripts.
  # Note: style-srcからnonceを除外してunsafe-inlineを有効化(Mermaid対応)
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w(script-src)

  # Report violations without enforcing the policy.
  # config.content_security_policy_report_only = true
end
