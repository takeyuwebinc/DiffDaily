# frozen_string_literal: true

module Admin
  class OmniauthCallbacksController < ApplicationController
    def google_oauth2
      auth = request.env["omniauth.auth"]
      email = auth.info.email

      unless allowed_domain?(email)
        redirect_to admin_login_path, alert: "許可されていないドメインです"
        return
      end

      session[:admin_user] = {
        email: email,
        name: auth.info.name,
        avatar_url: auth.info.image
      }

      redirect_to stored_location || admin_root_path, notice: "ログインしました"
    end

    def failure
      redirect_to admin_login_path, alert: "認証に失敗しました: #{params[:message]}"
    end

    private

    def allowed_domain?(email)
      allowed_domain = ENV.fetch("GOOGLE_OAUTH_ALLOWED_DOMAIN", "takeyuweb.co.jp")
      email.end_with?("@#{allowed_domain}")
    end

    def stored_location
      session.delete(:admin_return_to)
    end
  end
end
