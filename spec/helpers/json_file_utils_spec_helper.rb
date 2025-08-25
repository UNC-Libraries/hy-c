# frozen_string_literal: true
require 'rails_helper'
RSpec.describe JsonFileUtilsHelper do
  let(:tmpdir) { Dir.mktmpdir }
  after { FileUtils.remove_entry(tmpdir) rescue nil }

  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
  end

  describe '.write_json / .read_json' do
    let(:path) { File.join(tmpdir, 'nested', 'data.json') }
    let(:payload) { { 'a' => 1, 'b' => ['x', 'y'] } }

    it 'writes pretty JSON and reads it back' do
      expect(described_class.write_json(payload, path, pretty: true)).to be true
      expect(File).to exist(path)

      read = described_class.read_json(path)
      expect(read).to eq(payload)
      expect(Rails.logger).to have_received(:info).with(a_string_matching(/\[JsonFileUtilsHelper\] Wrote JSON to/))
    end

    it 'returns nil for missing file' do
      missing = File.join(tmpdir, 'nope.json')
      expect(described_class.read_json(missing)).to be_nil
    end

    it 'logs and returns false when write fails' do
      allow(File).to receive(:write).and_raise(StandardError, 'boom')
      expect(described_class.write_json(payload, path)).to be false
      expect(Rails.logger).to have_received(:warn).with(a_string_matching(/\[JsonFileUtilsHelper\] write_json failed .* boom/))
    end

    it 'logs and returns nil when read fails (bad JSON)' do
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "{bad json\n")
      expect(described_class.read_json(path)).to be_nil
      expect(Rails.logger).to have_received(:warn).with(a_string_matching(/\[JsonFileUtilsHelper\] read_json failed /))
    end
  end

  describe '.write_jsonl / .read_jsonl' do
    let(:path) { File.join(tmpdir, 'out', 'data.jsonl') }

    it 'writes records and reads them back' do
      records = [{ a: 1 }, { b: 2 }]
      count = described_class.write_jsonl(records, path)
      expect(count).to eq(2)
      expect(File).to exist(path)

      read = described_class.read_jsonl(path, symbolize_names: true)
      expect(read).to eq(records)
      expect(Rails.logger).to have_received(:info).with(a_string_matching(/\[JsonFileUtilsHelper\] Wrote 2 JSONL records/))
    end

    it 'appends when mode is "a"' do
      described_class.write_jsonl([{ a: 1 }], path, mode: 'w')
      described_class.write_jsonl([{ b: 2 }], path, mode: 'a')
      read = described_class.read_jsonl(path, symbolize_names: true)
      expect(read).to eq([{ a: 1 }, { b: 2 }])
    end

    it 'returns [] for missing file' do
      expect(described_class.read_jsonl(File.join(tmpdir, 'missing.jsonl'))).to eq([])
    end

    it 'logs and returns 0 when write_jsonl fails' do
      allow(File).to receive(:open).and_raise(StandardError, 'kaput')
      expect(described_class.write_jsonl([{ a: 1 }], path)).to eq(0)
      expect(Rails.logger).to have_received(:warn).with(a_string_matching(/\[JsonFileUtilsHelper\] write_jsonl failed .* kaput/))
    end

    it 'logs and returns [] when read_jsonl fails (bad line)' do
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, %({ "ok": 1 }\n{ bad json }\n))
      expect(described_class.read_jsonl(path)).to eq([])
      expect(Rails.logger).to have_received(:warn).with(a_string_matching(/\[JsonFileUtilsHelper\] read_jsonl failed /))
    end
  end

  describe '.ensure_dir' do
    it 'creates the parent directory if missing' do
      path = File.join(tmpdir, 'newdir', 'file.json')
      dir  = File.dirname(path)
      expect(Dir.exist?(dir)).to be false
      described_class.ensure_dir(path)
      expect(Dir.exist?(dir)).to be true
    end
  end
end
