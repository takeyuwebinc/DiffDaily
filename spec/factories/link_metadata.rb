FactoryBot.define do
  factory :link_metadatum do
    sequence(:url) { |n| "https://example.com/page/#{n}" }
    title { "Example Page Title" }
    description { "This is an example page description" }
    domain { "example.com" }
    favicon { "https://example.com/favicon.ico" }
    image_url { "https://example.com/image.png" }
    last_fetched_at { Time.current }
  end
end
