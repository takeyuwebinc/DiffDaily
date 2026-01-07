require "rails_helper"

RSpec.describe LinkMetadatum, type: :model do
  describe "validations" do
    subject { build(:link_metadatum) }

    it { is_expected.to validate_presence_of(:url) }
    it { is_expected.to validate_presence_of(:last_fetched_at) }
    it { is_expected.to validate_uniqueness_of(:url) }
  end

  describe ".fetch_metadata" do
    let(:url) { "https://github.com/example/repo/pull/123" }
    let(:html_response) do
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>feat: Add new feature by user · Pull Request #123</title>
          <meta property="og:title" content="feat: Add new feature">
          <meta property="og:description" content="This PR adds a new feature">
          <meta property="og:image" content="https://github.com/image.png">
          <meta name="description" content="This PR adds a new feature to the application">
          <link rel="icon" href="/favicon.ico">
        </head>
        <body></body>
        </html>
      HTML
    end

    context "when URL parameter is not provided" do
      it "returns error hash" do
        result = described_class.fetch_metadata(nil)
        expect(result).to eq({ error: "URL parameter is required" })
      end
    end

    context "when URL parameter is empty string" do
      it "returns error hash" do
        result = described_class.fetch_metadata("")
        expect(result).to eq({ error: "URL parameter is required" })
      end
    end

    context "when metadata is not cached" do
      before do
        allow(described_class).to receive(:fetch_html).with(url).and_return({
          success: true,
          html: html_response
        })
      end

      it "fetches metadata from URL and creates cache" do
        expect {
          described_class.fetch_metadata(url)
        }.to change(described_class, :count).by(1)

        created_metadata = described_class.find_by(url: url)
        expect(created_metadata.title).to eq("feat: Add new feature")
        expect(created_metadata.description).to eq("This PR adds a new feature")
        expect(created_metadata.domain).to eq("github.com")
        expect(created_metadata.favicon).to eq("https://github.com/favicon.ico")
        expect(created_metadata.image_url).to eq("https://github.com/image.png")
      end

      it "returns metadata hash" do
        result = described_class.fetch_metadata(url)

        expect(result).to eq({
          title: "feat: Add new feature",
          description: "This PR adds a new feature",
          domain: "github.com",
          favicon: "https://github.com/favicon.ico",
          imageUrl: "https://github.com/image.png"
        })
      end
    end

    context "when metadata is cached and valid" do
      let!(:cached_metadata) do
        create(:link_metadatum,
          url: url,
          title: "Cached Title",
          description: "Cached Description",
          domain: "github.com",
          favicon: "https://github.com/cached-favicon.ico",
          image_url: "https://github.com/cached-image.png",
          last_fetched_at: 1.hour.ago
        )
      end

      it "returns cached metadata without fetching" do
        expect(described_class).not_to receive(:fetch_html)

        result = described_class.fetch_metadata(url)

        expect(result).to eq({
          title: "Cached Title",
          description: "Cached Description",
          domain: "github.com",
          favicon: "https://github.com/cached-favicon.ico",
          imageUrl: "https://github.com/cached-image.png"
        })
      end
    end

    context "when metadata is cached but expired" do
      let!(:expired_metadata) do
        create(:link_metadatum,
          url: url,
          title: "Expired Title",
          description: "Expired Description",
          domain: "github.com",
          last_fetched_at: 25.hours.ago
        )
      end

      before do
        allow(described_class).to receive(:fetch_html).with(url).and_return({
          success: true,
          html: html_response
        })
      end

      it "fetches new metadata and updates cache" do
        expect {
          described_class.fetch_metadata(url)
        }.not_to change(described_class, :count)

        expired_metadata.reload
        expect(expired_metadata.title).to eq("feat: Add new feature")
        expect(expired_metadata.description).to eq("This PR adds a new feature")
        expect(expired_metadata.last_fetched_at).to be_within(1.second).of(Time.current)
      end
    end

    context "when HTML fetch encounters errors" do
      context "when HTTP request fails" do
        before do
          allow(described_class).to receive(:fetch_html).with(url).and_return({
            success: false,
            error: "HTTP 404: Failed to fetch URL"
          })
        end

        it "returns error hash with error messages" do
          result = described_class.fetch_metadata(url)
          expect(result).to eq({ error: "HTTP 404: Failed to fetch URL" })
        end
      end

      context "when unexpected exception occurs" do
        before do
          allow(described_class).to receive(:fetch_html).and_raise(StandardError.new("Unexpected error"))
          allow(Rails.error).to receive(:report)
          allow(Rails.logger).to receive(:error)
        end

        it "reports error and returns generic error message" do
          result = described_class.fetch_metadata(url)

          expect(Rails.error).to have_received(:report).with(
            instance_of(StandardError),
            context: { url: url }
          )
          expect(result).to eq({ error: "メタデータの取得中に問題が発生しました。しばらく経ってからもう一度お試しください。" })
        end
      end
    end
  end

  describe "#cache_valid?" do
    context "when last_fetched_at is within cache duration" do
      subject { build(:link_metadatum, last_fetched_at: 1.hour.ago) }

      it "returns true" do
        expect(subject.cache_valid?).to be true
      end
    end

    context "when last_fetched_at is outside cache duration" do
      subject { build(:link_metadatum, last_fetched_at: 25.hours.ago) }

      it "returns false" do
        expect(subject.cache_valid?).to be false
      end
    end
  end

  describe "#update_cache" do
    let(:metadata) do
      create(:link_metadatum,
        url: "https://example.com",
        title: "Old Title",
        description: "Old Description",
        domain: "example.com",
        favicon: "https://example.com/old-favicon.ico",
        image_url: "https://example.com/old-image.png",
        last_fetched_at: 2.hours.ago
      )
    end

    let(:new_metadata) do
      {
        title: "New Title",
        description: "New Description",
        domain: "example.com",
        favicon: "https://example.com/new-favicon.ico",
        imageUrl: "https://example.com/new-image.png"
      }
    end

    it "updates all metadata fields" do
      metadata.update_cache(new_metadata)

      expect(metadata.title).to eq("New Title")
      expect(metadata.description).to eq("New Description")
      expect(metadata.domain).to eq("example.com")
      expect(metadata.favicon).to eq("https://example.com/new-favicon.ico")
      expect(metadata.image_url).to eq("https://example.com/new-image.png")
      expect(metadata.last_fetched_at).to be_within(1.second).of(Time.current)
    end
  end

  describe ".cache_duration" do
    it "returns 24 hours by default" do
      expect(described_class.cache_duration).to eq(24.hours)
    end

    context "when custom cache duration is configured" do
      before do
        allow(Rails.application.config).to receive(:respond_to?)
          .and_return(true)
        allow(Rails.application.config).to receive(:link_metadata_cache_duration)
          .and_return(12.hours)
      end

      it "returns configured duration" do
        expect(described_class.cache_duration).to eq(12.hours)
      end
    end
  end
end
