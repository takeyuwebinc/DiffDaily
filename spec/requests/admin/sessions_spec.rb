# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Sessions", type: :request do
  describe "GET /admin/login" do
    it "displays the login page" do
      get admin_login_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sign in with Google")
    end

    context "when already logged in" do
      before do
        OmniAuth.config.test_mode = true
        OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
          provider: "google_oauth2",
          uid: "123456",
          info: {
            email: "test@takeyuweb.co.jp",
            name: "Test User",
            image: "https://example.com/avatar.png"
          }
        })
        get "/auth/google_oauth2/callback"
      end

      after do
        OmniAuth.config.test_mode = false
        OmniAuth.config.mock_auth[:google_oauth2] = nil
      end

      it "redirects to admin root" do
        get admin_login_path
        expect(response).to redirect_to(admin_root_path)
      end
    end
  end

  describe "DELETE /admin/logout" do
    it "destroys the session and redirects to root" do
      delete admin_logout_path
      expect(response).to redirect_to(root_path)
    end
  end
end
