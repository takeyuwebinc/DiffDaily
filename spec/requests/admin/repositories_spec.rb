# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Repositories", type: :request do
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

  describe "GET /admin/repositories" do
    it "displays the repository list" do
      repository = create(:repository)

      get admin_repositories_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(repository.name)
    end

    it "displays empty state when no repositories" do
      get admin_repositories_path
      expect(response.body).to include("No repositories registered yet")
    end
  end

  describe "GET /admin/repositories/new" do
    it "displays the new repository form" do
      get new_admin_repository_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Add Repository")
    end
  end

  describe "POST /admin/repositories" do
    context "with valid parameters" do
      let(:valid_params) do
        {
          repository: {
            name: "rails/rails",
            url: "https://github.com/rails/rails"
          }
        }
      end

      it "creates a new repository" do
        expect {
          post admin_repositories_path, params: valid_params
        }.to change(Repository, :count).by(1)
      end

      it "enqueues DailySummaryJob for initial fetch" do
        expect {
          post admin_repositories_path, params: valid_params
        }.to have_enqueued_job(DailySummaryJob)
      end

      it "redirects to the repository list" do
        post admin_repositories_path, params: valid_params
        expect(response).to redirect_to(admin_repositories_path)
      end
    end

    context "with invalid parameters" do
      let(:invalid_params) do
        {
          repository: {
            name: "",
            url: ""
          }
        }
      end

      it "does not create a repository" do
        expect {
          post admin_repositories_path, params: invalid_params
        }.not_to change(Repository, :count)
      end

      it "re-renders the form with errors" do
        post admin_repositories_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /admin/repositories/:id" do
    let!(:repository) { create(:repository) }

    it "deletes the repository" do
      expect {
        delete admin_repository_path(repository)
      }.to change(Repository, :count).by(-1)
    end

    it "redirects to the repository list" do
      delete admin_repository_path(repository)
      expect(response).to redirect_to(admin_repositories_path)
    end
  end
end
