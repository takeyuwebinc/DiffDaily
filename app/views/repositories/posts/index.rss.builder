xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.rss version: "2.0" do
  xml.channel do
    xml.title "DiffDaily - #{@repository.name}"
    xml.description "#{@repository.name}の変更をAIが要約"
    xml.link repository_posts_url(@repository)
    xml.language "ja"
    xml.lastBuildDate Time.current.rfc2822

    @posts.each do |post|
      xml.item do
        xml.title post.title
        xml.description post.summary
        xml.link post_url(post)
        xml.guid post_url(post), isPermaLink: "true"
        xml.pubDate post.published_at&.rfc2822
        xml.category post.repository.name
        xml.source "GitHub PR", url: post.source_url if post.source_url.present?
      end
    end
  end
end
