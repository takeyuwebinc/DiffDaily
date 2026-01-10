# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::OmniauthCallbacks", type: :request do
  before do
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  describe "GET /auth/google_oauth2/callback" do
    context "with allowed domain" do
      before do
        OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
          provider: "google_oauth2",
          uid: "123456",
          info: {
            email: "test@takeyuweb.co.jp",
            name: "Test User",
            image: "https://example.com/avatar.png"
          }
        })
      end

      it "logs in the user and redirects to admin root" do
        get "/auth/google_oauth2/callback"
        expect(response).to redirect_to(admin_root_path)
        follow_redirect!
        expect(response.body).to include("Dashboard")
      end

      it "stores user info in session" do
        get "/auth/google_oauth2/callback"
        follow_redirect!
        expect(response.body).to include("Test User")
      end
    end

    context "with disallowed domain" do
      before do
        OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
          provider: "google_oauth2",
          uid: "123456",
          info: {
            email: "test@example.com",
            name: "Test User",
            image: "https://example.com/avatar.png"
          }
        })
      end

      it "rejects login and redirects to login page" do
        get "/auth/google_oauth2/callback"
        expect(response).to redirect_to(admin_login_path)
      end

      it "shows an error message" do
        get "/auth/google_oauth2/callback"
        follow_redirect!
        expect(response.body).to include("許可されていないドメインです")
      end
    end

    context "with stored location" do
      before do
        OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
          provider: "google_oauth2",
          uid: "123456",
          info: {
            email: "test@takeyuweb.co.jp",
            name: "Test User",
            image: "https://example.com/avatar.png"
          }
        })
      end

      it "redirects to the stored location after login" do
        # 未認証でリポジトリページにアクセス
        get admin_repositories_path
        expect(response).to redirect_to(admin_login_path)

        # ログイン
        get "/auth/google_oauth2/callback"

        # 保存していたURLにリダイレクト
        expect(response).to redirect_to(admin_repositories_path)
      end
    end
  end

  describe "GET /auth/failure" do
    it "redirects to login page with error message" do
      get "/auth/failure", params: { message: "invalid_credentials" }
      expect(response).to redirect_to(admin_login_path)
    end
  end
end
