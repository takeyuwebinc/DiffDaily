# frozen_string_literal: true

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           ENV.fetch("GOOGLE_CLIENT_ID", nil),
           ENV.fetch("GOOGLE_CLIENT_SECRET", nil),
           {
             hd: ENV.fetch("GOOGLE_OAUTH_ALLOWED_DOMAIN", "takeyuweb.co.jp"),
             scope: "email,profile",
             prompt: "select_account",
             image_aspect_ratio: "square",
             image_size: 50
           }
end

OmniAuth.config.allowed_request_methods = [ :post ]
