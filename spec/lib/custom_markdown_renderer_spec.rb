require "rails_helper"

RSpec.describe CustomMarkdownRenderer do
  describe ".render" do
    context "when rendering code blocks" do
      it "renders a basic code block without filename" do
        markdown = <<~MD
          ```ruby
          puts "Hello, World!"
          ```
        MD

        html = described_class.render(markdown)

        expect(html).to include('<pre>')
        expect(html).to include('<code class="language-ruby">')
        expect(html).to include('puts "Hello, World!"')
        expect(html).not_to include('data-filename')
      end

      it "renders a code block with filename using colon notation" do
        markdown = <<~MD
          ```ruby:app/models/user.rb
          class User < ApplicationRecord
          end
          ```
        MD

        html = described_class.render(markdown)

        expect(html).to include('<pre data-filename="app/models/user.rb">')
        expect(html).to include('<code class="language-ruby">')
        expect(html).to include('class User &lt; ApplicationRecord')
      end

      it "renders a code block with special characters in filename" do
        markdown = <<~MD
          ```bash:~/.bash_profile
          export PATH=$PATH:/usr/local/bin
          ```
        MD

        html = described_class.render(markdown)

        expect(html).to include('<pre data-filename="~/.bash_profile">')
        expect(html).to include('<code class="language-bash">')
      end

      it "renders multiple code blocks with and without filenames" do
        markdown = <<~MD
          ```ruby:config/routes.rb
          Rails.application.routes.draw do
            root "posts#index"
          end
          ```

          Some text here.

          ```ruby
          puts "No filename"
          ```
        MD

        html = described_class.render(markdown)

        expect(html).to include('<pre data-filename="config/routes.rb">')
        expect(html).to include('Rails.application.routes.draw')
        expect(html).to include('<pre><code class="language-ruby">')
        expect(html).to include('puts "No filename"')
      end

      it "escapes HTML in filename" do
        markdown = <<~MD
          ```ruby:<script>alert('xss')</script>
          puts "test"
          ```
        MD

        html = described_class.render(markdown)

        expect(html).to include('data-filename="&lt;script&gt;alert(')
        expect(html).to include('xss')
        expect(html).to include('&lt;/script&gt;"')
        expect(html).not_to include('data-filename="<script>alert')
      end

      it "handles filenames with paths containing colons" do
        markdown = <<~MD
          ```typescript:C:/Users/name/project/file.ts
          const x: string = "test";
          ```
        MD

        html = described_class.render(markdown)

        expect(html).to include('data-filename="C:/Users/name/project/file.ts"')
        expect(html).to include('<code class="language-typescript">')
      end
    end

    context "when rendering mermaid diagrams" do
      it "renders mermaid code blocks with special mermaid markup" do
        markdown = <<~MD
          ```mermaid
          graph TD
            A[Start] --> B[End]
          ```
        MD

        html = described_class.render(markdown)

        expect(html).to include('class="mermaid-diagram"')
        expect(html).to include('data-controller="mermaid"')
        expect(html).to include('graph TD')
        expect(html).not_to include('data-filename')
      end
    end

    context "when sanitizing HTML" do
      it "preserves data-filename attribute after sanitization" do
        markdown = <<~MD
          ```ruby:test.rb
          puts "test"
          ```
        MD

        html = described_class.render(markdown)

        expect(html).to include('data-filename="test.rb"')
      end

      it "preserves data-controller attribute after sanitization" do
        markdown = <<~MD
          ```mermaid
          graph LR
            A --> B
          ```
        MD

        html = described_class.render(markdown)

        expect(html).to include('data-controller="mermaid"')
      end

      it "removes dangerous HTML tags" do
        markdown = <<~MD
          <script>alert('xss')</script>
          <img src=x onerror="alert('xss')">

          Safe content here.
        MD

        html = described_class.render(markdown)

        expect(html).not_to include('<script>')
        expect(html).not_to include('onerror=')
        expect(html).to include('Safe content here')
      end
    end

    context "when rendering other markdown features" do
      it "renders links with target=_blank" do
        markdown = "[Link](https://example.com)"
        html = described_class.render(markdown)

        expect(html).to include('target="_blank"')
        expect(html).to include('rel="noopener"')
      end

      it "renders tables" do
        markdown = <<~MD
          | Header 1 | Header 2 |
          |----------|----------|
          | Cell 1   | Cell 2   |
        MD

        html = described_class.render(markdown)

        expect(html).to include('<table>')
        expect(html).to include('<thead>')
        expect(html).to include('<tbody>')
        expect(html).to include('Header 1')
      end

      it "renders strikethrough" do
        markdown = "~~strikethrough~~"
        html = described_class.render(markdown)

        expect(html).to include('<del>')
        expect(html).to include('strikethrough')
      end
    end

    context "when handling edge cases" do
      it "returns empty string for nil input" do
        html = described_class.render(nil)
        expect(html).to eq("")
      end

      it "returns empty string for blank input" do
        html = described_class.render("")
        expect(html).to eq("")
      end

      it "handles code block with only language and colon (no filename)" do
        markdown = <<~MD
          ```ruby:
          puts "test"
          ```
        MD

        html = described_class.render(markdown)

        # Should render as normal code block without filename
        expect(html).to include('<code class="language-ruby">')
        expect(html).not_to include('data-filename=""')
      end
    end
  end

  describe ".sanitize_html" do
    it "allows specified tags" do
      html = "<p>Text</p><strong>Bold</strong><code>Code</code>"
      result = described_class.sanitize_html(html)

      expect(result).to include('<p>Text</p>')
      expect(result).to include('<strong>Bold</strong>')
      expect(result).to include('<code>Code</code>')
    end

    it "removes script tags" do
      html = "<p>Safe</p><script>alert('xss')</script>"
      result = described_class.sanitize_html(html)

      expect(result).to include('Safe')
      expect(result).not_to include('<script>')
    end

    it "preserves data-* attributes" do
      html = '<div data-controller="test" data-action="click">Content</div>'
      result = described_class.sanitize_html(html)

      expect(result).to include('data-controller="test"')
      expect(result).to include('data-action="click"')
    end
  end
end
