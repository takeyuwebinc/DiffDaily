require "cgi"

# カスタムMarkdown拡張機能モジュール
#
# このモジュールは、Redcarpetのレンダラーに拡張機能を追加するためのものです。
# 現在は、URLのみの行をリンクカードに変換する機能、mermaid図表の描画機能、
# 拡張画像表示機能、およびシンタックスハイライト機能を提供しています。
module CustomMarkdownExtensions
  # 拡張機能をレンダラーに登録する
  #
  # @param renderer [Redcarpet::Render::HTML] 拡張機能を登録するレンダラー
  # @return [void]
  def self.register_extensions(renderer)
    LinkCardExtension.register(renderer)
    MermaidExtension.register(renderer)
    ImageExtension.register(renderer)
    SyntaxHighlightExtension.register(renderer)
  end

  # リンクカード拡張モジュール
  #
  # このモジュールは、URLのみの行をリンクカードに変換する機能を提供します。
  module LinkCardExtension
    # リンクカード拡張機能をレンダラーに登録する
    #
    # @param renderer [Redcarpet::Render::HTML] 拡張機能を登録するレンダラー
    # @return [void]
    def self.register(renderer)
      # 前処理フックを追加
      original_preprocess = renderer.method(:preprocess) if renderer.respond_to?(:preprocess)

      renderer.define_singleton_method(:preprocess) do |document|
        # URLのみの行を検出してプレースホルダーに置き換え
        document = document.gsub(/^(https?:\/\/[^\s]+)$/m) do
          url = Regexp.last_match(1).strip
          # URLをdata属性に持つdivを生成（JavaScriptで検出するため）
          # noautolinkクラスを追加し、URLをエスケープして二重リンクを防止
          %(<div class="link-card-placeholder noautolink" data-controller="link-card" data-link-card-url-value="#{CGI.escape_html(url)}">
              <a href="#{CGI.escape_html(url)}" target="_blank" rel="noopener">#{url.gsub(/https?:\/\//, 'https&#58;//')}</a>
            </div>)
        end

        # 元の前処理メソッドを呼び出す
        if original_preprocess
          original_preprocess.call(document)
        else
          document
        end
      end
    end
  end

  # Mermaid図表拡張モジュール
  #
  # このモジュールは、Mermaid構文で記述されたコードブロックを図表として描画する機能を提供します。
  module MermaidExtension
    # Mermaid拡張機能をレンダラーに登録する
    #
    # @param renderer [Redcarpet::Render::HTML] 拡張機能を登録するレンダラー
    # @return [void]
    def self.register(renderer)
      # block_codeメソッドをオーバーライド
      original_block_code = renderer.method(:block_code) if renderer.respond_to?(:block_code)

      renderer.define_singleton_method(:block_code) do |code, language|
        if language == "mermaid"
          # Mermaid図表用のHTMLを生成
          escaped_code = CGI.escapeHTML(code)
          %(<div class="mermaid-diagram" data-controller="mermaid">
                <pre class="mermaid-source hidden">#{escaped_code}</pre>
                <div class="mermaid-render"></div>
              </div>)
        elsif original_block_code
          original_block_code.call(code, language)
        else
          # デフォルトのコードブロック生成
          escaped_code = CGI.escapeHTML(code)
          if language && !language.empty?
            escaped_language = CGI.escapeHTML(language)
            %(<pre><code class="language-#{escaped_language}">#{escaped_code}</code></pre>)
          else
            %(<pre><code>#{escaped_code}</code></pre>)
          end
        end
      end
    end
  end

  # 画像表示拡張モジュール
  #
  # このモジュールは、Markdown内の画像構文を拡張し、幅指定やキャプションなどの
  # 追加機能をサポートします。
  module ImageExtension
    # 画像拡張機能をレンダラーに登録する
    #
    # @param renderer [Redcarpet::Render::HTML] 拡張機能を登録するレンダラー
    # @return [void]
    def self.register(renderer)
      # 元のpreprocessメソッドを保存
      original_preprocess = renderer.method(:preprocess) if renderer.respond_to?(:preprocess)

      # 前処理フックを追加（キャプション検出用）
      renderer.define_singleton_method(:preprocess) do |document|
        # キャプションを検出して処理
        document = document.gsub(/!\[(.*?)\]\((.*?)\)[ \t]*\n\*(.*?)\*/) do
          alt_text = Regexp.last_match(1)
          image_path = Regexp.last_match(2)
          caption_text = Regexp.last_match(3).strip

          # 画像IDを生成
          image_id = "img-#{SecureRandom.hex(6)}"

          # 幅指定を抽出
          width = nil
          clean_path = image_path
          if image_path =~ /\s*=\s*(\d+)px\s*$/
            width = Regexp.last_match(1).to_i
            clean_path = image_path.gsub(/\s*=\s*\d+px\s*$/, "").strip
          end

          # 幅指定がある場合はスタイルを追加
          width_style = width ? %( style="width: #{width}px;") : ""

          # 画像とキャプションを含むHTMLを生成
          %(<figure class="my-6" id="#{image_id}">
  <img src="#{CGI.escape_html(clean_path)}" alt="#{CGI.escape_html(alt_text)}" class="max-w-full h-auto rounded-md mx-auto"#{width_style} />
  <figcaption class="text-sm text-gray-600 text-center mt-2">#{CGI.escape_html(caption_text)}</figcaption>
</figure>)
        end

        # 元の前処理メソッドを呼び出す
        if original_preprocess
          original_preprocess.call(document)
        else
          document
        end
      end

      # 元のpostprocessメソッドを保存
      original_postprocess = renderer.method(:postprocess) if renderer.respond_to?(:postprocess)

      # 後処理フックを追加（画像の処理）
      renderer.define_singleton_method(:postprocess) do |document|
        # リンク付き画像を検出して処理
        document = document.gsub(/<p><a href="([^"]+)"><img src="([^"]+)" alt="([^"]*)"[^>]*><\/a><\/p>/) do
          link_url = Regexp.last_match(1)
          img_src = Regexp.last_match(2)
          alt_text = Regexp.last_match(3)

          # 画像IDを生成
          image_id = "img-#{SecureRandom.hex(6)}"

          # 幅指定を抽出
          width = nil
          clean_path = img_src
          if img_src =~ /\s*=\s*(\d+)px\s*$/
            width = Regexp.last_match(1).to_i
            clean_path = img_src.gsub(/\s*=\s*\d+px\s*$/, "").strip
          end

          # 幅指定がある場合はスタイルを追加
          width_style = width ? %( style="width: #{width}px;") : ""

          # リンク付き画像を生成
          %(<figure class="my-6" id="#{image_id}">
  <a href="#{link_url}" target="_blank" rel="noopener">
    <img src="#{clean_path}" alt="#{alt_text}" class="max-w-full h-auto rounded-md mx-auto"#{width_style} />
  </a>
</figure>)
        end

        # 通常の画像を検出して処理（既に処理済みのfigure要素は除外）
        document = document.gsub(/<p><img src="([^"]+)" alt="([^"]*)"[^>]*><\/p>/) do |match|
          img_src = Regexp.last_match(1)
          alt_text = Regexp.last_match(2)

          # 既にfigure要素内にある場合はスキップ
          prefix = Regexp.last_match.pre_match
          next match if prefix.include?("<figure") && !prefix.include?("</figure>")

          # 画像IDを生成
          image_id = "img-#{SecureRandom.hex(6)}"

          # 幅指定を抽出
          width = nil
          clean_path = img_src
          if img_src =~ /\s*=\s*(\d+)px\s*$/
            width = Regexp.last_match(1).to_i
            clean_path = img_src.gsub(/\s*=\s*\d+px\s*$/, "").strip
          end

          # 幅指定がある場合はスタイルを追加
          width_style = width ? %( style="width: #{width}px;") : ""

          # 画像を生成
          %(<figure class="my-6" id="#{image_id}">
  <img src="#{clean_path}" alt="#{alt_text}" class="max-w-full h-auto rounded-md mx-auto"#{width_style} />
</figure>)
        end

        # 元の後処理メソッドを呼び出す
        if original_postprocess
          original_postprocess.call(document)
        else
          document
        end
      end
    end
  end

  # シンタックスハイライト拡張モジュール
  #
  # このモジュールは、コードブロックにシンタックスハイライト機能を提供します。
  # ファイル名表示機能もサポートしています。
  module SyntaxHighlightExtension
    # シンタックスハイライト拡張機能をレンダラーに登録する
    #
    # @param renderer [Redcarpet::Render::HTML] 拡張機能を登録するレンダラー
    # @return [void]
    def self.register(renderer)
      # block_codeメソッドをオーバーライド
      original_block_code = renderer.method(:block_code) if renderer.respond_to?(:block_code)

      renderer.define_singleton_method(:block_code) do |code, language|
        if language.present? && language != "mermaid"
          # 言語とファイル名を分離
          lang, filename = SyntaxHighlightExtension.parse_language_and_filename(language)

          if filename.present?
            # ファイル名付きコードブロックのHTMLを生成
            SyntaxHighlightExtension.generate_code_block_with_filename(code, lang, filename)
          else
            # 通常のコードブロックのHTMLを生成
            SyntaxHighlightExtension.generate_code_block(code, lang)
          end
        elsif original_block_code
          original_block_code.call(code, language)
        else
          # デフォルトのコードブロック生成
          escaped_code = CGI.escapeHTML(code)
          if language && !language.empty?
            escaped_language = CGI.escapeHTML(language)
            %(<pre><code class="language-#{escaped_language}">#{escaped_code}</code></pre>)
          else
            %(<pre><code>#{escaped_code}</code></pre>)
          end
        end
      end
    end

    # 言語文字列からファイル名を分離する
    #
    # @param language [String] 言語文字列（例: "bash:~/.bash_profile"）
    # @return [Array<String>] [言語, ファイル名] の配列
    def self.parse_language_and_filename(language)
      if language.include?(":")
        parts = language.split(":", 2)
        lang = parts[0].strip
        filename = parts[1].strip
        filename = nil if filename.empty?
        [lang, filename]
      else
        [language.strip, nil]
      end
    end

    # ファイル名付きコードブロックのHTMLを生成する
    #
    # @param code [String] コード内容
    # @param language [String] プログラミング言語
    # @param filename [String] ファイル名
    # @return [String] 生成されたHTML
    def self.generate_code_block_with_filename(code, language, filename)
      escaped_code = CGI.escapeHTML(code)
      escaped_language = CGI.escapeHTML(language)
      escaped_filename = CGI.escapeHTML(filename)

      %(<pre data-filename="#{escaped_filename}"><code class="language-#{escaped_language}">#{escaped_code}</code></pre>)
    end

    # 通常のコードブロックのHTMLを生成する
    #
    # @param code [String] コード内容
    # @param language [String] プログラミング言語
    # @return [String] 生成されたHTML
    def self.generate_code_block(code, language)
      escaped_code = CGI.escapeHTML(code)
      escaped_language = CGI.escapeHTML(language)

      %(<pre><code class="language-#{escaped_language}">#{escaped_code}</code></pre>)
    end
  end
end
