require "rails_helper"
require_relative "../../lib/custom_markdown_renderer"

RSpec.describe CustomMarkdownExtensions do
  describe CustomMarkdownExtensions::SyntaxHighlightExtension do
    describe ".parse_language_and_filename" do
      it "parses language with filename" do
        lang, filename = described_class.parse_language_and_filename("ruby:app/models/user.rb")

        expect(lang).to eq("ruby")
        expect(filename).to eq("app/models/user.rb")
      end

      it "parses language without filename" do
        lang, filename = described_class.parse_language_and_filename("ruby")

        expect(lang).to eq("ruby")
        expect(filename).to be_nil
      end

      it "handles language with colon but empty filename" do
        lang, filename = described_class.parse_language_and_filename("ruby:")

        expect(lang).to eq("ruby")
        expect(filename).to be_nil
      end

      it "handles filename with multiple colons" do
        lang, filename = described_class.parse_language_and_filename("typescript:C:/path/to/file.ts")

        expect(lang).to eq("typescript")
        expect(filename).to eq("C:/path/to/file.ts")
      end

      it "handles special characters in filename" do
        lang, filename = described_class.parse_language_and_filename("bash:~/.bash_profile")

        expect(lang).to eq("bash")
        expect(filename).to eq("~/.bash_profile")
      end

      it "trims whitespace from language and filename" do
        lang, filename = described_class.parse_language_and_filename("  ruby  :  test.rb  ")

        expect(lang).to eq("ruby")
        expect(filename).to eq("test.rb")
      end
    end

    describe ".generate_code_block_with_filename" do
      it "generates HTML with data-filename attribute" do
        html = described_class.generate_code_block_with_filename(
          "puts 'hello'",
          "ruby",
          "test.rb"
        )

        expect(html).to include('<pre data-filename="test.rb">')
        expect(html).to include('<code class="language-ruby">')
        expect(html).to include('puts &#39;hello&#39;')
      end

      it "escapes HTML in code content" do
        html = described_class.generate_code_block_with_filename(
          "<script>alert('xss')</script>",
          "html",
          "malicious.html"
        )

        expect(html).to include('&lt;script&gt;')
        expect(html).not_to include('<script>')
      end

      it "escapes HTML in filename" do
        html = described_class.generate_code_block_with_filename(
          "code",
          "ruby",
          "<script>alert('xss')</script>"
        )

        expect(html).to include('data-filename="&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"')
        expect(html).not_to include('data-filename="<script>')
      end

      it "escapes HTML in language" do
        html = described_class.generate_code_block_with_filename(
          "code",
          "<script>",
          "file.txt"
        )

        expect(html).to include('class="language-&lt;script&gt;"')
        expect(html).not_to include('class="language-<script>')
      end
    end

    describe ".generate_code_block" do
      it "generates HTML without data-filename attribute" do
        html = described_class.generate_code_block(
          "puts 'hello'",
          "ruby"
        )

        expect(html).to include('<pre>')
        expect(html).to include('<code class="language-ruby">')
        expect(html).not_to include('data-filename')
        expect(html).to include('puts &#39;hello&#39;')
      end

      it "escapes HTML in code content" do
        html = described_class.generate_code_block(
          "<div>test</div>",
          "html"
        )

        expect(html).to include('&lt;div&gt;test&lt;/div&gt;')
        expect(html).not_to include('<div>test</div>')
      end

      it "escapes HTML in language" do
        html = described_class.generate_code_block(
          "code",
          "<script>"
        )

        expect(html).to include('class="language-&lt;script&gt;"')
        expect(html).not_to include('class="language-<script>')
      end
    end
  end

  describe "Integration with renderer" do
    let(:renderer) do
      CustomHTMLRenderer.new(
        hard_wrap: true,
        link_attributes: { target: "_blank", rel: "noopener" }
      )
    end

    before do
      described_class.register_extensions(renderer)
    end

    describe "block_code rendering" do
      it "renders mermaid diagrams" do
        html = renderer.block_code("graph TD\n  A --> B", "mermaid")

        expect(html).to include('class="mermaid-diagram"')
        expect(html).to include('data-controller="mermaid"')
        expect(html).to include('graph TD')
      end

      it "renders code with filename" do
        html = renderer.block_code("class User\nend", "ruby:models/user.rb")

        expect(html).to include('data-filename="models/user.rb"')
        expect(html).to include('class="language-ruby"')
        expect(html).to include('class User')
      end

      it "renders code without filename" do
        html = renderer.block_code("puts 'hello'", "ruby")

        expect(html).not_to include('data-filename')
        expect(html).to include('class="language-ruby"')
        expect(html).to include('puts &#39;hello&#39;')
      end

      it "renders code with empty language" do
        html = renderer.block_code("plain text", nil)

        expect(html).to include('<pre>')
        expect(html).to include('plain text')
        # nil language falls back to default plaintext
      end

      it "handles language with colon but no filename" do
        html = renderer.block_code("code", "ruby:")

        expect(html).to include('class="language-ruby"')
        expect(html).not_to include('data-filename=""')
      end
    end

    describe "extension registration" do
      it "registers all extensions in correct order" do
        fresh_renderer = CustomHTMLRenderer.new

        expect(described_class).to receive(:register_extensions).and_call_original
        described_class.register_extensions(fresh_renderer)

        # Verify that the renderer has the extended block_code method
        html = fresh_renderer.block_code("test", "ruby:file.rb")
        expect(html).to include('data-filename="file.rb"')
      end
    end
  end

  describe "Mermaid diagram compatibility" do
    it "does not interfere with mermaid rendering after syntax highlight registration" do
      renderer = CustomHTMLRenderer.new
      described_class.register_extensions(renderer)

      mermaid_code = <<~MERMAID
        graph LR
          A[Start] --> B[Process]
          B --> C[End]
      MERMAID

      html = renderer.block_code(mermaid_code, "mermaid")

      expect(html).to include('mermaid-diagram')
      expect(html).to include('data-controller="mermaid"')
      expect(html).not_to include('data-filename')
      expect(html).not_to include('class="language-mermaid"')
    end
  end

  describe "Security" do
    let(:renderer) do
      r = CustomHTMLRenderer.new
      described_class.register_extensions(r)
      r
    end

    it "escapes XSS attempts in filename" do
      html = renderer.block_code(
        "code",
        "ruby:<script>alert('xss')</script>"
      )

      expect(html).not_to include("<script>alert('xss')</script>")
      expect(html).to include("&lt;script&gt;")
    end

    it "escapes XSS attempts in code content" do
      html = renderer.block_code(
        "<img src=x onerror='alert(1)'>",
        "html"
      )

      expect(html).not_to include("<img src=x")
      expect(html).to include("&lt;img src=x")
    end

    it "handles potentially malicious language strings" do
      html = renderer.block_code(
        "test",
        "' onload='alert(1)"
      )

      # The language string is HTML-escaped, preventing XSS
      expect(html).to include("&#39;")
      expect(html).to include("alert(1)")
      # Even though "onload=" appears in escaped form, it cannot execute
      expect(html).not_to include("' onload='alert(1)'")
    end
  end
end
