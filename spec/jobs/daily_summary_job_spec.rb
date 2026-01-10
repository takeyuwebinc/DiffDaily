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

    describe 'last_fetched_at management' do
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

      context 'when last_fetched_at is nil (first run)' do
        it 'uses 24 hours ago as since parameter' do
          now = Time.current
          travel_to(now) do
            described_class.perform_now(repository.id)
            expect(Github::FetchRecentChanges).to have_received(:perform)
              .with(repository.name, since: be_within(1.second).of(now - 24.hours))
          end
        end

        it 'updates last_fetched_at after successful completion' do
          now = Time.current
          travel_to(now) do
            expect {
              described_class.perform_now(repository.id)
            }.to change { repository.reload.last_fetched_at }.from(nil).to(be_within(1.second).of(now))
          end
        end
      end

      context 'when last_fetched_at is already set' do
        let(:previous_fetch_time) { 2.days.ago }

        before do
          repository.update!(last_fetched_at: previous_fetch_time)
        end

        it 'uses last_fetched_at as since parameter' do
          described_class.perform_now(repository.id)
          expect(Github::FetchRecentChanges).to have_received(:perform)
            .with(repository.name, since: be_within(1.second).of(previous_fetch_time))
        end

        it 'updates last_fetched_at to current time' do
          now = Time.current
          travel_to(now) do
            expect {
              described_class.perform_now(repository.id)
            }.to change { repository.reload.last_fetched_at }.to(be_within(1.second).of(now))
          end
        end
      end

      context 'when no PRs are found' do
        before do
          allow(Github::FetchRecentChanges).to receive(:perform).and_return([])
        end

        it 'still updates last_fetched_at' do
          now = Time.current
          travel_to(now) do
            expect {
              described_class.perform_now(repository.id)
            }.to change { repository.reload.last_fetched_at }.from(nil).to(be_within(1.second).of(now))
          end
        end
      end
    end
  end
end
