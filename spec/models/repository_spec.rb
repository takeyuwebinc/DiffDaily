require 'rails_helper'

RSpec.describe Repository do
  describe 'associations' do
    it { is_expected.to have_many(:posts).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:repository) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_presence_of(:url) }

    context 'url format validation' do
      it 'accepts valid http URLs' do
        repository = build(:repository, url: 'http://github.com/test/repo')
        expect(repository).to be_valid
      end

      it 'accepts valid https URLs' do
        repository = build(:repository, url: 'https://github.com/test/repo')
        expect(repository).to be_valid
      end

      it 'rejects invalid URLs' do
        repository = build(:repository, url: 'invalid-url')
        expect(repository).not_to be_valid
        expect(repository.errors[:url]).to be_present
      end
    end
  end

  describe 'dependent destroy' do
    it 'destroys associated posts when repository is destroyed' do
      repository = create(:repository)
      post = create(:post, repository: repository)

      expect { repository.destroy }.to change { Post.count }.by(-1)
    end
  end
end
