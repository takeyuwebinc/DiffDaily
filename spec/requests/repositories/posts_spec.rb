require 'rails_helper'

RSpec.describe "Repositories::Posts" do
  describe "GET /repositories/:repository_id/posts" do
    let(:repository) { create(:repository) }

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
        get repository_posts_path(repository)
        expect(response).to have_http_status(:success)
      end

      it "displays only published posts" do
        get repository_posts_path(repository)
        expect(response.body).to include(published_posts[0].title)
        expect(response.body).to include(published_posts[1].title)
        expect(response.body).to include(published_posts[2].title)
        expect(response.body).not_to include(draft_post.title)
        expect(response.body).not_to include(skipped_post.title)
      end

      it "orders posts by published_at descending" do
        get repository_posts_path(repository)
        body = response.body
        pos1 = body.index(published_posts[1].title)
        pos2 = body.index(published_posts[2].title)
        pos3 = body.index(published_posts[0].title)

        expect(pos1).to be < pos2
        expect(pos2).to be < pos3
      end

      it "displays repository name in header" do
        get repository_posts_path(repository)
        expect(response.body).to include(repository.name)
      end

      it "displays link to repository URL" do
        get repository_posts_path(repository)
        expect(response.body).to include(repository.url)
      end

      it "displays link to top page" do
        get repository_posts_path(repository)
        expect(response.body).to include(root_path)
      end
    end

    context "with posts from other repositories" do
      let(:other_repository) { create(:repository) }
      let!(:my_post) { create(:post, :published, repository: repository) }
      let!(:other_post) { create(:post, :published, repository: other_repository) }

      it "displays only posts from the specified repository" do
        get repository_posts_path(repository)
        expect(response.body).to include(my_post.title)
        expect(response.body).not_to include(other_post.title)
      end
    end

    context "with pagination" do
      let!(:posts_list) do
        25.times.map do |i|
          create(:post, :published, repository: repository, published_at: (25 - i).days.ago)
        end
      end

      it "displays first page of posts" do
        get repository_posts_path(repository)
        expect(response).to have_http_status(:success)
        posts_list.reverse.first(20).each do |post|
          expect(response.body).to include(post.title)
        end
      end

      it "displays second page with remaining posts" do
        get repository_posts_path(repository), params: { page: 2 }
        expect(response).to have_http_status(:success)
        posts_list.reverse.last(5).each do |post|
          expect(response.body).to include(post.title)
        end
      end
    end

    context "without posts" do
      it "returns success status" do
        get repository_posts_path(repository)
        expect(response).to have_http_status(:success)
      end
    end

    context "with non-existent repository" do
      it "returns 404 status" do
        get repository_posts_path(repository_id: 99999)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /repositories/:repository_id/posts.rss" do
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
        get repository_posts_path(repository, format: :rss)
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("application/rss+xml")
      end

      it "returns valid RSS 2.0 XML with repository info" do
        get repository_posts_path(repository, format: :rss)
        doc = Nokogiri::XML(response.body)
        expect(doc.at_xpath("//rss/@version").value).to eq("2.0")
        expect(doc.at_xpath("//channel/title").text).to eq("DiffDaily - rails/rails")
        expect(doc.at_xpath("//channel/language").text).to eq("ja")
      end

      it "includes only published posts from the repository" do
        get repository_posts_path(repository, format: :rss)
        doc = Nokogiri::XML(response.body)
        titles = doc.xpath("//item/title").map(&:text)
        expect(titles).to include("Post 1", "Post 2", "Post 3")
        expect(titles).not_to include("Draft Post")
      end

      it "orders posts by published_at descending" do
        get repository_posts_path(repository, format: :rss)
        doc = Nokogiri::XML(response.body)
        titles = doc.xpath("//item/title").map(&:text)
        expect(titles).to eq(["Post 2", "Post 3", "Post 1"])
      end
    end

    context "with posts from other repositories" do
      let(:other_repository) { create(:repository, name: "other/repo") }
      let!(:my_post) { create(:post, :published, repository: repository, title: "My Post") }
      let!(:other_post) { create(:post, :published, repository: other_repository, title: "Other Post") }

      it "includes only posts from the specified repository" do
        get repository_posts_path(repository, format: :rss)
        doc = Nokogiri::XML(response.body)
        titles = doc.xpath("//item/title").map(&:text)
        expect(titles).to include("My Post")
        expect(titles).not_to include("Other Post")
      end
    end

    context "with more than 50 posts" do
      let!(:posts_list) do
        55.times.map do |i|
          create(:post, :published, repository: repository, published_at: (55 - i).days.ago)
        end
      end

      it "limits to 50 posts" do
        get repository_posts_path(repository, format: :rss)
        doc = Nokogiri::XML(response.body)
        expect(doc.xpath("//item").count).to eq(50)
      end
    end

    context "with non-existent repository" do
      it "returns 404 status" do
        get repository_posts_path(repository_id: 99999, format: :rss)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
