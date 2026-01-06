FactoryBot.define do
  factory :repository do
    sequence(:name) { |n| "test-repo-#{n}" }
    url { "https://github.com/test/#{name}" }
  end
end
