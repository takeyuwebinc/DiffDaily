class Repository < ApplicationRecord
  has_many :posts, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }

  scope :with_published_posts, -> {
    joins(:posts).where(posts: { status: :published }).distinct
  }
end
