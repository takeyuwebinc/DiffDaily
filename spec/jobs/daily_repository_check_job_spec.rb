require 'rails_helper'

RSpec.describe DailyRepositoryCheckJob, type: :job do
  describe '#perform' do
    context 'when no repositories exist' do
      it 'completes without error' do
        expect { described_class.perform_now }.not_to raise_error
      end

      it 'logs that no repositories were found' do
        allow(Rails.logger).to receive(:info)
        described_class.perform_now
        expect(Rails.logger).to have_received(:info).with("No repositories found")
      end
    end

    context 'when repositories exist with different last_fetched_at states' do
      let!(:never_fetched) { create(:repository, name: 'org/never-fetched', last_fetched_at: nil) }
      let!(:recently_fetched) { create(:repository, name: 'org/recently-fetched', last_fetched_at: 1.hour.ago) }
      let!(:due_for_fetch) { create(:repository, name: 'org/due-for-fetch', last_fetched_at: 25.hours.ago) }

      before do
        allow(DailySummaryJob).to receive(:perform_now)
      end

      it 'fetches repositories that have never been fetched (last_fetched_at is nil)' do
        described_class.perform_now
        expect(DailySummaryJob).to have_received(:perform_now).with(never_fetched.id)
      end

      it 'fetches repositories that are due for fetching (past fetch interval)' do
        described_class.perform_now
        expect(DailySummaryJob).to have_received(:perform_now).with(due_for_fetch.id)
      end

      it 'skips repositories that were recently fetched (within fetch interval)' do
        described_class.perform_now
        expect(DailySummaryJob).not_to have_received(:perform_now).with(recently_fetched.id)
      end

      it 'logs the number of due repositories' do
        allow(Rails.logger).to receive(:info)
        described_class.perform_now
        expect(Rails.logger).to have_received(:info).with(/Found 2 repositories due for fetching/)
      end
    end

    context 'when no repositories are due for fetching' do
      let!(:recently_fetched1) { create(:repository, name: 'org/recent1', last_fetched_at: 1.hour.ago) }
      let!(:recently_fetched2) { create(:repository, name: 'org/recent2', last_fetched_at: 12.hours.ago) }

      it 'does not call DailySummaryJob' do
        expect(DailySummaryJob).not_to receive(:perform_now)
        described_class.perform_now
      end

      it 'logs that no repositories are due' do
        allow(Rails.logger).to receive(:info)
        described_class.perform_now
        expect(Rails.logger).to have_received(:info).with(/No repositories due for fetching/)
      end
    end

    context 'when an error occurs for one repository' do
      let!(:repository1) { create(:repository, name: 'org/repo1', last_fetched_at: nil) }
      let!(:repository2) { create(:repository, name: 'org/repo2', last_fetched_at: nil) }

      before do
        allow(DailySummaryJob).to receive(:perform_now).with(repository1.id).and_raise(StandardError, "Test error")
        allow(DailySummaryJob).to receive(:perform_now).with(repository2.id)
      end

      it 'continues processing other repositories' do
        expect { described_class.perform_now }.not_to raise_error
        expect(DailySummaryJob).to have_received(:perform_now).with(repository2.id)
      end

      it 'logs the error' do
        allow(Rails.logger).to receive(:error)
        allow(Rails.logger).to receive(:info)
        described_class.perform_now
        expect(Rails.logger).to have_received(:error).with(/Failed to fetch repository org\/repo1/)
      end
    end

    context 'boundary condition: exactly at fetch interval' do
      let!(:exactly_due) { create(:repository, name: 'org/exactly-due', last_fetched_at: 24.hours.ago) }

      before do
        allow(DailySummaryJob).to receive(:perform_now)
      end

      it 'fetches repository when exactly at the fetch interval boundary' do
        described_class.perform_now
        expect(DailySummaryJob).to have_received(:perform_now).with(exactly_due.id)
      end
    end
  end

  describe 'FETCH_INTERVAL constant' do
    it 'is set to 24 hours' do
      expect(described_class::FETCH_INTERVAL).to eq(24.hours)
    end
  end
end
