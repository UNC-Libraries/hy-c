# frozen_string_literal: true
require 'rails_helper'
require 'redlock'
require Rails.root.join('app/overrides/lib/hydra/derivatives/processors/ffmpeg_locking.rb')

RSpec.describe Hydra::Derivatives::Processors::FfmpegLocking do
  let(:mock_lock_manager) { instance_double(Redlock::Client) }
  let(:lock_key) { 'ffmpeg_process_lock' }
  let(:lock_expiry) { 60 * 30 * 1000 }

  before do
    # Reset the cached lock manager
    if described_class.instance_variable_defined?(:@lock_manager)
      described_class.remove_instance_variable(:@lock_manager)
    end

    # Mock Redis.current used in lock_manager
    allow(Redis).to receive(:current).and_return(double('redis_instance'))
    allow(Redlock::Client).to receive(:new).and_return(mock_lock_manager)
  end

  describe '.lock_manager' do
    it 'returns a singleton lock manager instance' do
      expect(Redlock::Client).to receive(:new).once.and_return(mock_lock_manager)

      # Call twice to verify singleton behavior
      manager1 = described_class.lock_manager
      manager2 = described_class.lock_manager

      expect(manager1).to eq(mock_lock_manager)
      expect(manager2).to eq(mock_lock_manager)
    end
  end

  describe '.with_ffmpeg_lock' do
    context 'when lock is successfully acquired' do
      it 'yields the block' do
        expect(mock_lock_manager).to receive(:lock)
          .with(lock_key, lock_expiry)
          .and_yield(true)

        expect { |b| described_class.with_ffmpeg_lock(&b) }.to yield_control
      end
    end

    context 'when lock is not acquired' do
      before do
        # Mock the sleep method to avoid actual waiting in tests
        allow(described_class).to receive(:sleep)
        allow(Rails.logger).to receive(:debug)
      end

      it 'retries after lock acquisition failure' do
        # First attempt fails, second attempt succeeds
        call_count = 0
        expect(mock_lock_manager).to receive(:lock)
          .with(lock_key, lock_expiry)
          .twice do |&block|
            call_count += 1
            if call_count == 1
              # First call: simulate lock failure
              block.call(false)
            else
              # Second call: simulate lock success
              block.call(true)
            end
          end

        # Track that sleep was called between retries
        expect(described_class).to receive(:sleep).once.with(0.5)

        # Verify the error is logged
        expect(Rails.logger).to receive(:debug).with('Failed to acquire ffmpeg lock')

        # Execute the block should be called exactly once
        executed = false
        described_class.with_ffmpeg_lock { executed = true }
        expect(executed).to be true
      end
    end
  end
end
