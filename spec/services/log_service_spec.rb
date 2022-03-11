require 'rails_helper'

RSpec.describe LogService do
  it 'knows the valid log levels' do
    expect(described_class.valid_log_levels).to eq([:debug, :info, :warn, :error, :fatal, :unknown])
  end
  context 'with the environment variable set to debug' do
    around do |example|
      cached_log_level = ENV['LOG_LEVEL']
      ENV['LOG_LEVEL'] = 'debug'
      example.run
      ENV['LOG_LEVEL'] = cached_log_level
    end

    it 'sets the log level' do
      expect(described_class.log_level).to eq(:debug)
    end
  end
  context 'with the environment variable set to warn' do
    around do |example|
      cached_log_level = ENV['LOG_LEVEL']
      ENV['LOG_LEVEL'] = 'warn'
      example.run
      ENV['LOG_LEVEL'] = cached_log_level
    end

    it 'sets the log level' do
      expect(described_class.log_level).to eq(:warn)
    end
  end
  context 'with the environment variable unset' do
    around do |example|
      cached_log_level = ENV['LOG_LEVEL']
      ENV.delete('LOG_LEVEL')
      example.run
      ENV['LOG_LEVEL'] = cached_log_level
    end

    it 'sets the log level' do
      expect(described_class.log_level).to eq(:warn)
    end
  end
  context 'with the environment variable set to an illegal value' do
    around do |example|
      cached_log_level = ENV['LOG_LEVEL']
      ENV['LOG_LEVEL'] = 'potato_chips'
      example.run
      ENV['LOG_LEVEL'] = cached_log_level
    end

    it 'sets the log level' do
      expect(described_class.log_level).to eq(:warn)
    end
  end
end
