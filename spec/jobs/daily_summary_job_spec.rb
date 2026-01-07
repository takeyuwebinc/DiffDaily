require 'rails_helper'

RSpec.describe DailySummaryJob, type: :job do
  let(:repository) { create(:repository, name: 'rails/rails') }
  let(:merged_at) { 1.day.ago }
  let(:pr_data) do
    {
      number: 123,
      title: "Test PR",
      url: "https://github.com/rails/rails/pull/123",
      body: "Test description",
      merged_at: merged_at,
      diff: []
    }
  end

  describe '#perform' do
    context 'when repository exists' do
      before do
        allow(Github::FetchRecentChanges).to receive(:perform).and_return([pr_data])
        allow(Content::GenerateArticle).to receive(:new).and_return(
          double(
            perform: {
              article: "# Test Article\n\nContent",
              summary: "Test summary",
              review_status: "approved",
              review_attempts: 1,
              review_issues: [],
              merged_at: merged_at
            },
            model_name: "Claude Sonnet 4.5"
          )
        )
      end

      it 'creates a post for new PR' do
        expect {
          described_class.perform_now(repository.id)
        }.to change(Post, :count).by(1)
      end

      it 'sets published_at to PR merged_at time' do
        described_class.perform_now(repository.id)
        post = Post.last
        expect(post.published_at).to be_within(1.second).of(merged_at)
      end

      context 'when post already exists for the same PR' do
        before do
          create(:post, repository: repository, source_url: pr_data[:url], title: "Existing Post")
        end

        it 'does not create duplicate post' do
          expect {
            described_class.perform_now(repository.id)
          }.not_to change(Post, :count)
        end

        it 'logs that the PR was skipped' do
          allow(Rails.logger).to receive(:info)
          described_class.perform_now(repository.id)
          expect(Rails.logger).to have_received(:info).with(/already exists as post/)
        end
      end
    end

    context 'when repository does not exist' do
      it 'does not raise error' do
        expect {
          described_class.perform_now(99999)
        }.not_to raise_error
      end
    end
  end
end
