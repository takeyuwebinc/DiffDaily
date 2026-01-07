require "rails_helper"

RSpec.describe "Api::LinkCards", type: :request do
  describe "GET /api/link_cards/metadata" do
    let(:url) { "https://github.com/example/repo/pull/123" }
    let(:metadata) do
      {
        title: "feat: Add new feature",
        description: "This PR adds a new feature to the application",
        domain: "github.com",
        favicon: "https://github.com/favicon.ico",
        imageUrl: "https://github.com/image.png"
      }
    end

    context "when URL parameter is provided" do
      context "when metadata is successfully fetched" do
        before do
          allow(LinkMetadatum).to receive(:fetch_metadata).with(url).and_return(metadata)
        end

        it "returns metadata as JSON" do
          get metadata_api_link_cards_path, params: { url: url }

          expect(response).to have_http_status(:ok)
          expect(response.content_type).to match(%r{application/json})

          json_response = JSON.parse(response.body, symbolize_names: true)
          expect(json_response).to eq(metadata)
        end
      end

      context "when metadata fetch fails" do
        let(:error_message) { "Failed to fetch metadata" }

        before do
          allow(LinkMetadatum).to receive(:fetch_metadata)
            .with(url)
            .and_return({ error: error_message })
        end

        it "returns error response" do
          get metadata_api_link_cards_path, params: { url: url }

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.content_type).to match(%r{application/json})

          json_response = JSON.parse(response.body, symbolize_names: true)
          expect(json_response).to eq({ error: error_message })
        end
      end
    end

    context "when URL parameter is not provided" do
      before do
        allow(LinkMetadatum).to receive(:fetch_metadata)
          .with(nil)
          .and_return({ error: "URL parameter is required" })
      end

      it "returns bad request error" do
        get metadata_api_link_cards_path

        expect(response).to have_http_status(:bad_request)
        expect(response.content_type).to match(%r{application/json})

        json_response = JSON.parse(response.body, symbolize_names: true)
        expect(json_response).to eq({ error: "URL parameter is required" })
      end
    end

    context "when URL parameter is empty string" do
      before do
        allow(LinkMetadatum).to receive(:fetch_metadata)
          .with("")
          .and_return({ error: "URL parameter is required" })
      end

      it "returns bad request error" do
        get metadata_api_link_cards_path, params: { url: "" }

        expect(response).to have_http_status(:bad_request)
        expect(response.content_type).to match(%r{application/json})

        json_response = JSON.parse(response.body, symbolize_names: true)
        expect(json_response).to eq({ error: "URL parameter is required" })
      end
    end
  end
end
