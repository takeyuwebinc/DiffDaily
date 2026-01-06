FactoryBot.define do
  factory :post do
    association :repository
    sequence(:title) { |n| "Test Post #{n}" }
    body { "This is a test post body with meaningful content." }
    status { :draft }
    published_at { nil }

    trait :published do
      status { :published }
      published_at { Time.current }
    end

    trait :skipped do
      status { :skipped }
    end
  end
end
