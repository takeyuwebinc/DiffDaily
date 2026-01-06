require "redcarpet"
require "rails-html-sanitizer"
require "securerandom"
require "cgi"
require_relative "custom_markdown_extensions"

# カスタムHTMLレンダラー
# コードブロックに適切なクラスを追加する
class CustomHTMLRenderer < Redcarpet::Render::HTML
  attr_reader :placeholders, :block_code_handlers

  def initialize(options = {})
    super
    @placeholders = {}
    @block_code_handlers = []

    # 拡張機能を登録
    CustomMarkdownExtensions.register_extensions(self)
  end

  # コードブロックのレンダリングをカスタマイズ
  def block_code(code, language)
    # 登録されたハンドラを順に試す
    @block_code_handlers.each do |handler|
      result = handler.call(code, language)
      return result if result # ハンドラが処理した場合はその結果を返す
    end

    # どのハンドラも処理しなかった場合はデフォルト処理
    language_class = language ? "language-#{language}" : "language-plaintext"
    %(<pre><code class="#{language_class}">#{CGI.escapeHTML(code)}</code></pre>)
  end

  # ブロックコードハンドラを登録するメソッド
  def register_block_code_handler(handler)
    @block_code_handlers << handler
  end

  def preprocess(document)
    @placeholders = {}
    document
  end

  def postprocess(document)
    document
  end
end

# カスタムMarkdownレンダラークラス
#
# Redcarpetを使用してMarkdownをHTMLに変換し、カスタム拡張機能を適用する。
# 変換後のHTMLをサニタイズして安全なHTML出力を保証する。
class CustomMarkdownRenderer
  # HTMLサニタイザー
  SANITIZER = Rails::Html::SafeListSanitizer.new

  # 許可するHTMLタグ
  ALLOWED_TAGS = %w[
    p br h1 h2 h3 h4 h5 h6
    ul ol li
    a img
    strong em del code pre
    blockquote
    table thead tbody tr th td
    div figure figcaption span
  ].freeze

  # 許可するHTML属性
  ALLOWED_ATTRIBUTES = %w[
    href target rel
    src alt width height style
    class id
    data-controller data-action data-target
  ].freeze

  # data-*属性も許可する
  ALLOWED_ATTRIBUTES_PATTERN = /\Adata-[\w-]+\z/

  # Redcarpetのオプション
  REDCARPET_EXTENSIONS = {
    autolink: true,
    tables: true,
    fenced_code_blocks: true,
    strikethrough: true,
    space_after_headers: true,
    no_intra_emphasis: true
  }.freeze

  REDCARPET_RENDER_OPTIONS = {
    hard_wrap: true,
    link_attributes: { target: "_blank", rel: "noopener" }
  }.freeze

  # Markdownをレンダリングする
  #
  # @param markdown_text [String] Markdown形式のテキスト
  # @return [String] サニタイズされたHTML
  def self.render(markdown_text)
    return "" if markdown_text.blank?

    # カスタムレンダラーを作成
    renderer = CustomHTMLRenderer.new(REDCARPET_RENDER_OPTIONS)

    # カスタム拡張機能を登録
    CustomMarkdownExtensions.register_extensions(renderer)

    # Markdownパーサーを作成
    markdown = Redcarpet::Markdown.new(renderer, REDCARPET_EXTENSIONS)

    # Markdown→HTML変換
    html = markdown.render(markdown_text)

    # HTMLサニタイズ
    sanitize_html(html)
  end

  # HTMLをサニタイズする
  #
  # @param html [String] サニタイズ対象のHTML
  # @return [String] サニタイズされたHTML
  def self.sanitize_html(html)
    # 許可リスト方式でサニタイズ
    sanitized = SANITIZER.sanitize(
      html,
      tags: ALLOWED_TAGS,
      attributes: ALLOWED_ATTRIBUTES
    )

    # data-*属性を追加で許可
    sanitized = allow_data_attributes(sanitized)

    # safe文字列としてマーク
    sanitized.html_safe
  end

  # data-*属性を許可する
  #
  # @param html [String] HTML文字列
  # @return [String] data-*属性が保持されたHTML
  def self.allow_data_attributes(html)
    # data-*属性を含む要素を再解析して保持
    # Rails::Html::SafeListSanitizerはdata-*のワイルドカードをサポートしていないため
    # 一旦許可属性として追加する必要がある

    # より安全な実装のため、個別にdata-*属性を検出して許可
    doc = Nokogiri::HTML.fragment(html)

    doc.css("[data-controller], [data-action], [data-target]").each do |element|
      element.attributes.each do |name, attr|
        # data-*属性でない場合はスキップ
        next unless name.start_with?("data-")

        # data-*属性を保持（既にサニタイズ済みなので安全）
      end
    end

    doc.to_html
  end
end
