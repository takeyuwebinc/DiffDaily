module Api
  # URLのメタデータを取得するAPIコントローラー
  class LinkCardsController < ApplicationController
    # URLからメタデータを取得するエンドポイント
    #
    # @note このエンドポイントは、URLからメタデータ（タイトル、説明、ドメイン、ファビコン、画像URL）を取得します。
    #   キャッシュがある場合はキャッシュから取得し、ない場合は外部サイトから取得します。
    #
    # @param url [String] メタデータを取得するURL（クエリパラメータ）
    # @return [JSON] メタデータのJSON（タイトル、説明、ドメイン、ファビコン、画像URL）
    #   または、エラーが発生した場合はエラー情報を含むJSON
    # @example
    #   GET /api/link_cards/metadata?url=https://example.com
    def metadata
      url = params[:url]
      result = LinkMetadatum.fetch_metadata(url)

      if result[:error].present?
        # エラーがある場合はエラーレスポンスを返す
        status = url.present? ? :unprocessable_entity : :bad_request
        render json: { error: result[:error] }, status: status
      else
        # 成功した場合はメタデータを返す
        render json: result
      end
    end
  end
end
