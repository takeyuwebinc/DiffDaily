require 'rails_helper'

RSpec.describe DailyRepositoryCheckJob, type: :job do
  describe '#perform' do
    context 'when repositories exist' do
      let!(:repository1) { create(:repository, name: 'rails/rails') }
      let!(:repository2) { create(:repository, name: 'ruby/ruby') }

      it 'calls DailySummaryJob for each repository' do
        expect(DailySummaryJob).to receive(:perform_now).with(repository1.id)
        expect(DailySummaryJob).to receive(:perform_now).with(repository2.id)

        described_class.perform_now
      end
    end

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

    context 'when an error occurs for one repository' do
      let!(:repository1) { create(:repository, name: 'rails/rails') }
      let!(:repository2) { create(:repository, name: 'ruby/ruby') }

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
        described_class.perform_now
        expect(Rails.logger).to have_received(:error).with(/Failed to check repository rails\/rails/)
      end
    end
  end
end
