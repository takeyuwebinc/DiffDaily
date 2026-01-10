class PostsController < ApplicationController
  def index
    @repositories = Repository.with_published_posts
    @posts = Post.published.page(params[:page]).per(20)
  end

  def show
    @post = Post.find(params[:id])
    set_meta_tags
  end

  private

  def set_meta_tags
    # ページタイトル
    set_page_title(@post.title)

    # OGタグとTwitterカード用のメタデータ
    set_meta_description(generate_description)
    set_og_tags
    set_twitter_card_tags
  end

  def set_page_title(title)
    @page_title = title
  end

  def generate_description
    # summaryフィールドがある場合はそれを使用、なければタイトルを使用
    description = @post.summary.presence || @post.title
    description.truncate(200)
  end

  def set_meta_description(description)
    @meta_description = description
  end

  def set_og_tags
    @og_title = @post.title
    @og_description = @meta_description
    @og_url = post_url(@post)
    @og_type = "article"
    # 記事の公開日時
    @og_article_published_time = @post.published_at&.iso8601
  end

  def set_twitter_card_tags
    @twitter_card = "summary_large_image"
    @twitter_title = @post.title
    @twitter_description = @meta_description
    # 必要に応じて画像URLを設定
    # @twitter_image = "https://yourdomain.com/default-og-image.png"
  end
end
