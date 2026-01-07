require "rails_helper"

RSpec.describe Content::GenerateArticle, type: :action do
  let(:repository_name) { "basecamp/kamal" }
  let(:pr_data) do
    {
      number: 123,
      title: "Add health check support",
      body: "This PR adds health check support for better monitoring.",
      url: "https://github.com/basecamp/kamal/pull/123",
      diff: [
        {
          filename: "lib/kamal/health_check.rb",
          status: "added",
          additions: 20,
          deletions: 0,
          patch: <<~PATCH
            +class Kamal::HealthCheck
            +  def initialize(url)
            +    @url = url
            +  end
            +
            +  def perform
            +    Net::HTTP.get_response(URI(@url))
            +  end
            +end
          PATCH
        }
      ]
    }
  end

  let(:action) { described_class.new(repository_name, pr_data) }

  describe "#perform" do
    let(:anthropic_client) { instance_double(Anthropic::Client) }
    let(:messages_api) { instance_double("Messages") }
    let(:gemini_client) { double("Gemini") }

    before do
      # テスト用の環境変数を設定
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return("test_anthropic_key")
      allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return("test_gemini_key")

      # Claude client のモック
      allow(Anthropic::Client).to receive(:new).and_return(anthropic_client)
      allow(anthropic_client).to receive(:messages).and_return(messages_api)

      # Gemini client のモック
      allow(Gemini).to receive(:new).and_return(gemini_client)
    end

    context "記事が生成され、精査に成功した場合" do
      let(:generated_article) do
        {
          "article" => "# [basecamp/kamal] ヘルスチェック機能の追加\n\n...",
          "summary" => "Kamalにヘルスチェック機能が追加されました。"
        }
      end

      let(:review_result) do
        {
          "approved" => true,
          "issues" => [],
          "overall_feedback" => ""
        }
      end

      before do
        # 記事生成APIレスポンス (Claude)
        allow(messages_api).to receive(:create).with(
          hash_including(max_tokens: 4096)
        ).and_return(
          double(content: [double(text: generated_article.to_json)])
        ).once

        # 精査APIレスポンス (Gemini)
        gemini_response = [
          {
            "candidates" => [
              {
                "content" => {
                  "parts" => [
                    { "text" => review_result.to_json }
                  ]
                }
              }
            ]
          }
        ]
        allow(gemini_client).to receive(:stream_generate_content).and_return(gemini_response).once
      end

      it "生成された記事を返す" do
        result = action.perform

        expect(result).to be_present
        expect(result[:article]).to eq(generated_article["article"])
        expect(result[:summary]).to eq(generated_article["summary"])
        expect(result[:review_status]).to eq("approved")
        expect(result[:review_attempts]).to eq(1)
        expect(result[:review_issues]).to eq([])
      end

      it "リトライなしで承認される" do
        allow(Rails.logger).to receive(:info)

        action.perform

        expect(Rails.logger).to have_received(:info).with("Article approved after 0 retries")
      end
    end

    context "記事が精査で不合格となり、リトライ後に合格する場合" do
      let(:first_article) do
        {
          "article" => "# 最初の記事（問題あり）",
          "summary" => "初回生成"
        }
      end

      let(:first_review) do
        {
          "approved" => false,
          "issues" => [
            {
              "category" => "guideline",
              "severity" => "critical",
              "description" => "技術詳細が不足しています",
              "suggestion" => "コード例を追加してください"
            }
          ],
          "overall_feedback" => "技術的な詳細が不足しています"
        }
      end

      let(:second_article) do
        {
          "article" => "# [basecamp/kamal] ヘルスチェック機能の追加（改善版）",
          "summary" => "改善された記事"
        }
      end

      let(:second_review) do
        {
          "approved" => true,
          "issues" => [],
          "overall_feedback" => ""
        }
      end

      before do
        call_count = 0

        # 記事生成APIレスポンス（1回目と2回目で異なるレスポンス）
        allow(messages_api).to receive(:create).with(
          hash_including(max_tokens: 4096)
        ) do
          call_count += 1
          if call_count == 1
            double(content: [double(text: first_article.to_json)])
          else
            double(content: [double(text: second_article.to_json)])
          end
        end

        review_count = 0

        # 精査APIレスポンス（1回目は不合格、2回目は合格）- Gemini
        allow(gemini_client).to receive(:stream_generate_content) do
          review_count += 1
          if review_count == 1
            [{ "candidates" => [{ "content" => { "parts" => [{ "text" => first_review.to_json }] } }] }]
          else
            [{ "candidates" => [{ "content" => { "parts" => [{ "text" => second_review.to_json }] } }] }]
          end
        end
      end

      it "リトライ後に改善された記事を返す" do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:warn)

        result = action.perform

        expect(result).to be_present
        expect(result[:article]).to eq(second_article["article"])
        expect(result[:summary]).to eq(second_article["summary"])
        expect(result[:review_status]).to eq("approved_with_retry")
        expect(result[:review_attempts]).to eq(2) # 1回目失敗 + 2回目成功
        expect(result[:review_issues]).to eq([])
      end

      it "リトライログが記録される" do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:warn)

        action.perform

        expect(Rails.logger).to have_received(:info).with(/Article review failed/)
        expect(Rails.logger).to have_received(:info).with("Article approved after 1 retries")
      end
    end

    context "記事がSKIPと判定された場合" do
      before do
        allow(messages_api).to receive(:create).with(
          hash_including(max_tokens: 4096)
        ).and_return(
          double(content: [double(text: "SKIP")])
        ).once
      end

      it "nilを返す" do
        result = action.perform
        expect(result).to be_nil
      end
    end

    context "精査が最大リトライ回数を超えた場合" do
      let(:article_with_issues) do
        {
          "article" => "# 問題のある記事",
          "summary" => "品質は低いが公開可能"
        }
      end

      let(:failed_review) do
        {
          "approved" => false,
          "issues" => [
            {
              "category" => "technical",
              "severity" => "warning",
              "description" => "軽微な問題",
              "suggestion" => "改善推奨"
            }
          ],
          "overall_feedback" => "改善の余地あり"
        }
      end

      before do
        # 記事生成を3回実行（初回+リトライ2回）
        allow(messages_api).to receive(:create).with(
          hash_including(max_tokens: 4096)
        ).and_return(
          double(content: [double(text: article_with_issues.to_json)])
        ).exactly(3).times

        # 精査も3回実行（すべて不合格）- Gemini
        gemini_failed_response = [
          {
            "candidates" => [
              {
                "content" => {
                  "parts" => [
                    { "text" => failed_review.to_json }
                  ]
                }
              }
            ]
          }
        ]
        allow(gemini_client).to receive(:stream_generate_content).and_return(gemini_failed_response).exactly(3).times
      end

      it "リトライ上限後も記事を返す" do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:warn)

        result = action.perform

        expect(result).to be_present
        expect(result[:article]).to eq(article_with_issues["article"])
        expect(result[:review_status]).to eq("approved_with_issues")
        expect(result[:review_attempts]).to eq(3) # 3回すべて失敗
        expect(result[:review_issues]).to be_present
      end

      it "警告ログが記録される" do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:warn)

        action.perform

        expect(Rails.logger).to have_received(:warn).with("Article review failed after 2 retries")
        expect(Rails.logger).to have_received(:warn).with(/Issues:/)
      end
    end
  end
end
