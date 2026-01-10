require 'rails_helper'

RSpec.describe "Posts" do
  let(:repository) { create(:repository) }

  describe "GET /posts" do
    context "with published posts" do
      let!(:published_posts) do
        [
          create(:post, :published, repository: repository, published_at: 3.days.ago),
          create(:post, :published, repository: repository, published_at: 1.day.ago),
          create(:post, :published, repository: repository, published_at: 2.days.ago)
        ]
      end
      let!(:draft_post) { create(:post, repository: repository, status: :draft) }
      let!(:skipped_post) { create(:post, :skipped, repository: repository) }

      it "returns success status" do
        get posts_path
        expect(response).to have_http_status(:success)
      end

      it "displays only published posts" do
        get posts_path
        expect(response.body).to include(published_posts[0].title)
        expect(response.body).to include(published_posts[1].title)
        expect(response.body).to include(published_posts[2].title)
        expect(response.body).not_to include(draft_post.title)
        expect(response.body).not_to include(skipped_post.title)
      end

      it "orders posts by published_at descending" do
        get posts_path
        body = response.body
        pos1 = body.index(published_posts[1].title)
        pos2 = body.index(published_posts[2].title)
        pos3 = body.index(published_posts[0].title)

        expect(pos1).to be < pos2
        expect(pos2).to be < pos3
      end
    end

    context "with pagination" do
      let!(:posts_list) do
        25.times.map do |i|
          create(:post, :published, repository: repository, published_at: (25 - i).days.ago)
        end
      end

      it "displays first page of posts" do
        get posts_path
        expect(response).to have_http_status(:success)
        # Posts are ordered by published_at desc, so most recent 20 posts should be visible
        posts_list.reverse.first(20).each do |post|
          expect(response.body).to include(post.title)
        end
      end

      it "displays second page with remaining posts" do
        get posts_path, params: { page: 2 }
        expect(response).to have_http_status(:success)
        # Remaining 5 oldest posts should be visible
        posts_list.reverse.last(5).each do |post|
          expect(response.body).to include(post.title)
        end
      end
    end

    context "without posts" do
      it "returns success status" do
        get posts_path
        expect(response).to have_http_status(:success)
      end
    end

    context "with repository list" do
      let(:repository_with_posts) { create(:repository, name: "repo-with-posts") }
      let(:repository_without_posts) { create(:repository, name: "repo-without-posts") }
      let!(:published_post) { create(:post, :published, repository: repository_with_posts) }

      it "displays repositories with published posts" do
        get posts_path
        expect(response.body).to include(repository_with_posts.name)
      end

      it "does not display repositories without published posts" do
        get posts_path
        expect(response.body).not_to include(repository_without_posts.name)
      end

      it "displays link to repository posts page" do
        get posts_path
        expect(response.body).to include(repository_posts_path(repository_with_posts))
      end
    end
  end

  describe "GET /posts/:id" do
    let(:post) { create(:post, :published, repository: repository) }

    it "returns success status" do
      get post_path(post)
      expect(response).to have_http_status(:success)
    end

    it "displays the post title" do
      get post_path(post)
      expect(response.body).to include(post.title)
    end

    it "displays the post body" do
      get post_path(post)
      expect(response.body).to include(post.body)
    end

    context "with non-existent post" do
      it "returns 404 status" do
        get post_path(id: 99999)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with draft post" do
      let(:draft_post) { create(:post, repository: repository, status: :draft) }

      it "still displays the post" do
        get post_path(draft_post)
        expect(response).to have_http_status(:success)
        expect(response.body).to include(draft_post.title)
      end
    end

    context "with repository link" do
      it "displays link to repository posts page" do
        get post_path(post)
        expect(response.body).to include(repository_posts_path(repository))
      end
    end
  end

  describe "GET /" do
    it "routes to posts#index" do
      get root_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /posts.rss" do
    let(:repository) { create(:repository, name: "rails/rails") }

    context "with published posts" do
      let!(:published_posts) do
        [
          create(:post, :published, repository: repository, title: "Post 1", summary: "Summary 1", source_url: "https://github.com/rails/rails/pull/1", published_at: 3.days.ago),
          create(:post, :published, repository: repository, title: "Post 2", summary: "Summary 2", source_url: "https://github.com/rails/rails/pull/2", published_at: 1.day.ago),
          create(:post, :published, repository: repository, title: "Post 3", summary: "Summary 3", source_url: "https://github.com/rails/rails/pull/3", published_at: 2.days.ago)
        ]
      end
      let!(:draft_post) { create(:post, repository: repository, status: :draft, title: "Draft Post") }

      it "returns success status with RSS content type" do
        get posts_path(format: :rss)
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("application/rss+xml")
      end

      it "returns valid RSS 2.0 XML" do
        get posts_path(format: :rss)
        doc = Nokogiri::XML(response.body)
        expect(doc.at_xpath("//rss/@version").value).to eq("2.0")
        expect(doc.at_xpath("//channel/title").text).to eq("DiffDaily")
        expect(doc.at_xpath("//channel/language").text).to eq("ja")
      end

      it "includes only published posts" do
        get posts_path(format: :rss)
        doc = Nokogiri::XML(response.body)
        titles = doc.xpath("//item/title").map(&:text)
        expect(titles).to include("Post 1", "Post 2", "Post 3")
        expect(titles).not_to include("Draft Post")
      end

      it "orders posts by published_at descending" do
        get posts_path(format: :rss)
        doc = Nokogiri::XML(response.body)
        titles = doc.xpath("//item/title").map(&:text)
        expect(titles).to eq(["Post 2", "Post 3", "Post 1"])
      end

      it "includes required item elements" do
        get posts_path(format: :rss)
        doc = Nokogiri::XML(response.body)
        item = doc.at_xpath("//item")

        expect(item.at_xpath("title")).to be_present
        expect(item.at_xpath("description")).to be_present
        expect(item.at_xpath("link")).to be_present
        expect(item.at_xpath("guid")).to be_present
        expect(item.at_xpath("pubDate")).to be_present
        expect(item.at_xpath("category")).to be_present
      end

      it "includes source URL when present" do
        get posts_path(format: :rss)
        doc = Nokogiri::XML(response.body)
        source = doc.at_xpath("//item/source")
        expect(source["url"]).to include("github.com")
      end
    end

    context "with more than 50 posts" do
      let!(:posts_list) do
        55.times.map do |i|
          create(:post, :published, repository: repository, published_at: (55 - i).days.ago)
        end
      end

      it "limits to 50 posts" do
        get posts_path(format: :rss)
        doc = Nokogiri::XML(response.body)
        expect(doc.xpath("//item").count).to eq(50)
      end
    end

    context "without posts" do
      it "returns success status with empty feed" do
        get posts_path(format: :rss)
        expect(response).to have_http_status(:success)
        doc = Nokogiri::XML(response.body)
        expect(doc.xpath("//item").count).to eq(0)
      end
    end
  end
end
