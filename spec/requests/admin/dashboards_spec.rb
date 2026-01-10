# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Dashboards", type: :request do
  describe "GET /admin" do
    context "when not logged in" do
      it "redirects to login page" do
        get admin_root_path
        expect(response).to redirect_to(admin_login_path)
      end
    end

    context "when logged in" do
      before do
        # OmniAuthの認証をシミュレート
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

        # コールバックを経由してログイン
        get "/auth/google_oauth2/callback"
      end

      after do
        OmniAuth.config.test_mode = false
        OmniAuth.config.mock_auth[:google_oauth2] = nil
      end

      it "displays the dashboard" do
        get admin_root_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Dashboard")
      end

      it "displays repository and post counts" do
        create_list(:repository, 2)
        create(:post)

        get admin_root_path
        expect(response.body).to include("Repositories")
        expect(response.body).to include("Posts")
      end
    end
  end
end
