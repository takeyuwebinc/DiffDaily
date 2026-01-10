require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#google_analytics_tag" do
    context "GA_MEASUREMENT_IDが設定されている場合" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("GA_MEASUREMENT_ID").and_return("G-Y5RT4N3HB5")
      end

      it "GA4スクリプトタグを出力する" do
        result = helper.google_analytics_tag
        expect(result).to include("https://www.googletagmanager.com/gtag/js?id=G-Y5RT4N3HB5")
        expect(result).to include("gtag('config', 'G-Y5RT4N3HB5'")
      end

      it "ページビュー送信コードを含む" do
        result = helper.google_analytics_tag
        expect(result).to include("gtag('event', 'page_view'")
      end

      it "Turbo Drive対応のイベントリスナーを含む" do
        result = helper.google_analytics_tag
        expect(result).to include("turbo:load")
      end
    end

    context "GA_MEASUREMENT_IDが未設定の場合" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("GA_MEASUREMENT_ID").and_return(nil)
      end

      it "nilを返す" do
        expect(helper.google_analytics_tag).to be_nil
      end
    end

    context "GA_MEASUREMENT_IDが空文字の場合" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("GA_MEASUREMENT_ID").and_return("")
      end

      it "nilを返す" do
        expect(helper.google_analytics_tag).to be_nil
      end
    end
  end
end
