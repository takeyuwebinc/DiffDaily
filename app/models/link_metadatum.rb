# URLメタデータのキャッシュを管理するモデル
#
# このモデルは、URLのメタデータ（タイトル、説明、ドメイン、ファビコン、画像URL）を
# キャッシュするために使用されます。キャッシュは一定期間（デフォルトで24時間）有効です。
class LinkMetadatum < ApplicationRecord
  validates :url, presence: true, uniqueness: true
  validates :last_fetched_at, presence: true

  # URLからメタデータを取得する
  #
  # @param url [String] メタデータを取得するURL
  # @return [Hash] メタデータのハッシュ（タイトル、説明、ドメイン、ファビコン、画像URL）
  #   または、エラーが発生した場合はエラー情報を含むハッシュ
  # @example
  #   LinkMetadatum.fetch_metadata('https://example.com')
  #   # => { title: 'Example Domain', description: '...', domain: 'example.com', ... }
  def self.fetch_metadata(url)
    return { error: "URL parameter is required" } unless url.present?

    # キャッシュを確認
    cached_metadata = find_by(url: url)

    # キャッシュが有効な場合
    if cached_metadata && cached_metadata.cache_valid?
      return {
        title: cached_metadata.title,
        description: cached_metadata.description,
        domain: cached_metadata.domain,
        favicon: cached_metadata.favicon,
        imageUrl: cached_metadata.image_url
      }
    end

    # キャッシュがない場合または無効な場合は新しく取得
    begin
      # HTTPクライアントでURLからHTMLを取得
      response = fetch_html(url)

      unless response[:success]
        return { error: response[:error] }
      end

      html = response[:html]
      parsed_url = URI.parse(url)

      # HTMLをパースしてメタデータを抽出
      doc = Nokogiri::HTML(html)

      # レスポンスデータを構築
      data = {
        title: extract_title(doc),
        description: extract_description(doc),
        domain: parsed_url.host,
        favicon: extract_favicon(doc, parsed_url),
        imageUrl: extract_image(doc, parsed_url)
      }

      # キャッシュを更新または作成
      if cached_metadata
        cached_metadata.update_cache(data)
      else
        create(
          url: url,
          title: data[:title],
          description: data[:description],
          domain: data[:domain],
          favicon: data[:favicon],
          image_url: data[:imageUrl],
          last_fetched_at: Time.current
        )
      end

      data
    rescue => e
      # エラーが発生した場合
      # Railsのエラーレポート機能を使用して報告
      Rails.error.report(e, context: { url: url })
      Rails.logger.error("LinkMetadatum.fetch_metadata error for URL #{url}: #{e.message}")
      # ユーザーには一般的なエラーメッセージを返す
      { error: "メタデータの取得中に問題が発生しました。しばらく経ってからもう一度お試しください。" }
    end
  end

  # キャッシュが有効かどうかを確認する
  #
  # @return [Boolean] キャッシュが有効な場合はtrue、そうでない場合はfalse
  # @example
  #   metadata = LinkMetadatum.find_by(url: 'https://example.com')
  #   metadata.cache_valid? # => true/false
  def cache_valid?
    last_fetched_at > self.class.cache_duration.ago
  end

  # キャッシュを更新する
  #
  # @param metadata [Hash] 更新するメタデータのハッシュ
  # @option metadata [String] :title タイトル
  # @option metadata [String] :description 説明
  # @option metadata [String] :domain ドメイン
  # @option metadata [String] :favicon ファビコンURL
  # @option metadata [String] :imageUrl 画像URL
  # @return [Boolean] 更新が成功した場合はtrue、そうでない場合はfalse
  # @example
  #   metadata = LinkMetadatum.find_by(url: 'https://example.com')
  #   metadata.update_cache({
  #     title: 'New Title',
  #     description: 'New Description',
  #     domain: 'example.com',
  #     favicon: 'https://example.com/favicon.ico',
  #     imageUrl: 'https://example.com/image.jpg'
  #   })
  def update_cache(metadata)
    update(
      title: metadata[:title],
      description: metadata[:description],
      domain: metadata[:domain],
      favicon: metadata[:favicon],
      image_url: metadata[:imageUrl],
      last_fetched_at: Time.current
    )
  end

  # キャッシュ期間を取得する
  #
  # @return [ActiveSupport::Duration] キャッシュ期間（デフォルトは24時間）
  # @example
  #   LinkMetadatum.cache_duration # => 24.hours
  def self.cache_duration
    Rails.application.config.respond_to?(:link_metadata_cache_duration) ?
      Rails.application.config.link_metadata_cache_duration :
      24.hours
  end

  private

  # URLからHTMLを取得する
  #
  # @param url [String] 取得するURL
  # @return [Hash] success, html, errorを含むハッシュ
  def self.fetch_html(url)
    conn = Faraday.new do |f|
      f.request :url_encoded
      f.response :follow_redirects, limit: 5
      f.adapter Faraday.default_adapter
      f.options.timeout = 10
      f.options.open_timeout = 5
    end

    response = conn.get(url) do |req|
      req.headers["User-Agent"] = "Mozilla/5.0 (compatible; DiffDaily/1.0; +https://diffdaily.example.com)"
    end

    if response.success?
      { success: true, html: response.body }
    else
      { success: false, error: "HTTP #{response.status}: Failed to fetch URL" }
    end
  rescue Faraday::Error => e
    { success: false, error: "Connection error: #{e.message}" }
  end

  # HTMLからタイトルを抽出
  #
  # @param doc [Nokogiri::HTML::Document] パース済みHTMLドキュメント
  # @return [String] タイトル
  def self.extract_title(doc)
    # OGタイトル、Twitterタイトル、通常のtitleタグの順で優先
    doc.at_css('meta[property="og:title"]')&.[]("content")&.strip ||
      doc.at_css('meta[name="twitter:title"]')&.[]("content")&.strip ||
      doc.at_css("title")&.text&.strip ||
      ""
  end

  # HTMLから説明を抽出
  #
  # @param doc [Nokogiri::HTML::Document] パース済みHTMLドキュメント
  # @return [String] 説明
  def self.extract_description(doc)
    # OG説明、Twitter説明、通常のdescription metaタグの順で優先
    doc.at_css('meta[property="og:description"]')&.[]("content")&.strip ||
      doc.at_css('meta[name="twitter:description"]')&.[]("content")&.strip ||
      doc.at_css('meta[name="description"]')&.[]("content")&.strip ||
      ""
  end

  # HTMLからファビコンURLを抽出
  #
  # @param doc [Nokogiri::HTML::Document] パース済みHTMLドキュメント
  # @param base_url [URI] ベースURL
  # @return [String] ファビコンURL
  def self.extract_favicon(doc, base_url)
    favicon_path = doc.at_css('link[rel~="icon"]')&.[]("href") ||
                   doc.at_css('link[rel~="shortcut icon"]')&.[]("href") ||
                   "/favicon.ico"

    absolute_url(favicon_path, base_url)
  end

  # HTMLから画像URLを抽出
  #
  # @param doc [Nokogiri::HTML::Document] パース済みHTMLドキュメント
  # @param base_url [URI] ベースURL
  # @return [String] 画像URL
  def self.extract_image(doc, base_url)
    image_path = doc.at_css('meta[property="og:image"]')&.[]("content") ||
                 doc.at_css('meta[name="twitter:image"]')&.[]("content") ||
                 ""

    return "" if image_path.empty?

    absolute_url(image_path, base_url)
  end

  # 相対URLを絶対URLに変換
  #
  # @param path [String] パス
  # @param base_url [URI] ベースURL
  # @return [String] 絶対URL
  def self.absolute_url(path, base_url)
    return path if path.start_with?("http://", "https://")
    return "" if path.empty?

    if path.start_with?("//")
      "#{base_url.scheme}:#{path}"
    elsif path.start_with?("/")
      "#{base_url.scheme}://#{base_url.host}#{path}"
    else
      "#{base_url.scheme}://#{base_url.host}/#{path}"
    end
  end
end
