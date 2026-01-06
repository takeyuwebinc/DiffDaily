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
  end

  describe "GET /" do
    it "routes to posts#index" do
      get root_path
      expect(response).to have_http_status(:success)
    end
  end
end
