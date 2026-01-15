# frozen_string_literal: true
require 'rails_helper'

RSpec.describe HtmlSanitizationRemediationService do
  let(:report_filepath) { '/tmp/html_sanitization_test.json' }
  let(:work_with_styling) { FactoryBot.create(:article, abstract: ['<p style="font-family: Arial; font-size: 14px;">Test abstract</p>']) }
  let(:solr_response) do
    {
      'response' => {
        'docs' => [
          { 'id' => work_with_styling.id }
        ]
      }
    }
  end

  before do
    allow(LogUtilsHelper).to receive(:double_log)
    allow(ActiveFedora::SolrService).to receive(:get).and_return(solr_response)
    allow(JsonFileUtilsHelper).to receive(:write_json)
  end

  after do
    File.delete(report_filepath) if File.exist?(report_filepath)
  end

  describe '.sanitize_existing_records' do
    context 'when no works found' do
      let(:solr_response) { { 'response' => { 'docs' => [] } } }

      it 'logs and returns early' do
        described_class.sanitize_existing_records(report_filepath: report_filepath, dry_run: true)

        expect(LogUtilsHelper).to have_received(:double_log).with(
          'No works found with disallowed styling',
          :info,
          tag: 'sanitize_existing_records'
        )
        expect(JsonFileUtilsHelper).not_to have_received(:write_json)
      end
    end

    context 'in dry run mode' do
      it 'does not modify works' do
        original_abstract = work_with_styling.abstract.first

        described_class.sanitize_existing_records(report_filepath: report_filepath, dry_run: true)

        work_with_styling.reload
        expect(work_with_styling.abstract.first).to eq(original_abstract)
      end

      it 'logs dry run actions' do
        described_class.sanitize_existing_records(report_filepath: report_filepath, dry_run: true)

        expect(LogUtilsHelper).to have_received(:double_log).with(
          "DRY RUN: Would sanitize #{work_with_styling.id}",
          :info,
          tag: 'sanitize_existing_records'
        )
      end

      it 'saves report with before/after preview' do
        described_class.sanitize_existing_records(report_filepath: report_filepath, dry_run: true)

        expect(JsonFileUtilsHelper).to have_received(:write_json) do |payload, path|
          expect(payload[:dry_run]).to be(true)
          expect(payload[:sanitized_count]).to eq(1)
          expect(payload[:results].first[:work_id]).to eq(work_with_styling.id)
          expect(payload[:results].first[:abstract][:before]).to include('font-family')
          expect(payload[:results].first[:abstract][:after]).not_to include('font-family')
        end
      end
    end

    context 'in live mode' do
      it 'strips disallowed styles from abstract' do
        described_class.sanitize_existing_records(report_filepath: report_filepath, dry_run: false)

        work_with_styling.reload
        expect(work_with_styling.abstract.first).not_to include('font-family')
        expect(work_with_styling.abstract.first).not_to include('font-size')
        expect(work_with_styling.abstract.first).to include('Test abstract')
      end

      it 'saves and reindexes work' do
        allow(work_with_styling).to receive(:save!)
        allow(work_with_styling).to receive(:update_index)
        allow(ActiveFedora::Base).to receive(:find).and_return(work_with_styling)

        described_class.sanitize_existing_records(report_filepath: report_filepath, dry_run: false)

        expect(work_with_styling).to have_received(:save!)
        expect(work_with_styling).to have_received(:update_index)
      end

      it 'logs completion' do
        described_class.sanitize_existing_records(report_filepath: report_filepath, dry_run: false)

        expect(LogUtilsHelper).to have_received(:double_log).with(
          'Sanitized 1 works',
          :info,
          tag: 'sanitize_existing_records'
        )
      end
    end

    context 'when work processing fails' do
      before do
        allow(ActiveFedora::Base).to receive(:find).and_raise(StandardError.new('Database error'))
      end

      it 'logs error and continues' do
        described_class.sanitize_existing_records(report_filepath: report_filepath, dry_run: true)

        expect(LogUtilsHelper).to have_received(:double_log).with(
          /Error processing work .+: Database error/,
          :error,
          tag: 'sanitize_existing_records'
        )
      end
    end
  end

  describe '.strip_disallowed_styles' do
    it 'removes font-family style' do
      html = '<p style="font-family: Arial;">Text</p>'
      result = described_class.send(:strip_disallowed_styles, html)
      expect(result).to eq('<p>Text</p>')
    end

    it 'removes font-size style' do
      html = '<p style="font-size: 14px;">Text</p>'
      result = described_class.send(:strip_disallowed_styles, html)
      expect(result).to eq('<p>Text</p>')
    end

    it 'removes font styles but preserves other styles' do
      html = '<div style="margin: 0px; font-family: Arial; padding: 10px; font-size: 14px; color: red;">Text</div>'
      result = described_class.send(:strip_disallowed_styles, html)
      expect(result).to eq('<div style="margin: 0px;padding: 10px;color: red;">Text</div>')
      expect(result).not_to include('font-family')
      expect(result).not_to include('font-size')
    end

    it 'removes entire style attribute if only font styles present' do
      html = '<span style="font-family: Arial; font-size: 14px;">Text</span>'
      result = described_class.send(:strip_disallowed_styles, html)
      expect(result).to eq('<span>Text</span>')
    end

    it 'handles complex Microsoft Word styles' do
      html = '<div style="margin: 0px; padding: 0px; font-family: Segoe UI, Arial; font-size: 12px; user-select: text;">Text</div>'
      result = described_class.send(:strip_disallowed_styles, html)
      expect(result).to eq('<div style="margin: 0px; padding: 0px;user-select: text;">Text</div>')
      expect(result).not_to include('font-family')
      expect(result).not_to include('font-size')
    end

    it 'handles quotes inside style attribute values' do
      html = %q(<span style="font-size: 12pt; font-family: 'Times New Roman',serif; line-height: 200%;">Text</span>)
      result = described_class.send(:strip_disallowed_styles, html)
      expect(result).to eq('<span style="line-height: 200%;">Text</span>')
      expect(result).not_to include('font-family')
      expect(result).not_to include('font-size')
    end

    it 'preserves other HTML' do
      html = '<p><strong>Bold</strong> and <em>italic</em></p>'
      result = described_class.send(:strip_disallowed_styles, html)
      expect(result).to eq(html)
    end

    it 'handles blank input' do
      expect(described_class.send(:strip_disallowed_styles, nil)).to be_nil
      expect(described_class.send(:strip_disallowed_styles, '')).to eq('')
    end
  end

  describe '.truncate_for_preview' do
    it 'truncates long text' do
      long_text = 'a' * 300
      result = described_class.send(:truncate_for_preview, long_text)
      expect(result.length).to eq(203) # 200 + '...'
      expect(result).to end_with('...')
    end

    it 'does not truncate short text' do
      short_text = 'Short text'
      result = described_class.send(:truncate_for_preview, short_text)
      expect(result).to eq(short_text)
    end

    it 'handles nil' do
      expect(described_class.send(:truncate_for_preview, nil)).to be_nil
    end
  end
end
