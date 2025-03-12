# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Hyrax::DepartmentsService do
  before do
    # Configure QA to use fixtures
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end
  let(:service) { described_class }

  describe '#select_all_options' do
    it 'returns only active terms' do
      expect(service.select_all_options).to include(['Biology', 'biology'], ['Chemistry', 'chemistry'],
                                                    ['History', 'history'],
                                                    ['Test short Carolina Center for Genome Sciences', 'Carolina Center for Genome Sciences'])
    end
  end

  describe '#term' do
    it 'resolves for ids of active terms' do
      expect(service.term('history')).to eq('History')
    end

    it 'resolves for ids of inactive terms' do
      expect(service.term('example')).to eq('Some College; Example Department')
    end

    it 'returns nil for blank input' do
      expect(service.term('')).to be_nil
    end
  end

  describe '#identifier' do
    it 'resolves for labels of active terms' do
      expect(service.identifier('History')).to eq('history')
    end

    it 'returns nil for blank input' do
      expect(service.identifier('')).to be_nil
    end
  end

  describe '#short_label' do
    it 'resolves for ids of active terms' do
      expect(service.short_label('history')).to eq('History')
    end

    it 'resolves for ids of inactive terms' do
      expect(service.short_label('example')).to eq('Example Department')
    end

    it 'returns nil for blank input' do
      expect(service.short_label('')).to be_nil
    end

    it 'logs but does not raise error for non-existent terms' do
      allow(Rails.logger).to receive(:debug)
      expect(service.short_label('not-a-department')).to be_nil
      expect(Rails.logger).to have_received(:debug)
    end
  end

  describe 'validate vocabulary terms' do
    it 'does not find any validation errors' do
      # Path to the YAML file
      yaml_file_path = 'config/authorities/departments.yml'

      # Load the YAML file
      departments = YAML.load_file(yaml_file_path)['terms']
      puts "Loaded #{departments.size} department entries from #{yaml_file_path}"

      # Build a lookup list of all department IDs
      department_ids = departments.map { |dept| dept['id'] }
      puts "Built lookup list with #{department_ids.size} department IDs"

      # Check for duplicates in the ID list
      duplicate_ids = department_ids.select { |id| department_ids.count(id) > 1 }.uniq
      unless duplicate_ids.empty?
        puts "Found duplicate IDs: #{duplicate_ids.join(', ')}"
      end

      # Track missing departments
      missing_departments = []
      invalid_term = false

      # Iterate through each department
      departments.each do |dept|
        id = dept['id']
        term = dept['term']

        # Skip if term is nil or not a string
        unless term.is_a?(String) || term.is_a?(Array)
          puts "Department '#{id}' has invalid or missing term field"
          invalid_term = true
          next
        end

        # Split the term field by semicolons and trim whitespace
        term_segments = Array(term).map { |val| val.split(';') }.flatten.map(&:strip)

        # Check each term segment against the ID lookup list
        term_segments.each do |segment|
          unless department_ids.include?(segment)
            missing_departments << {
              parent_id: id,
              missing_segment: segment
            }
            puts "Department '#{id}' references non-existent department '#{segment}' in its term field"
          end
        end
      end

      # Summary report
      if missing_departments.empty?
        puts 'Validation complete. All department references exist in the ID list.'
      else
        puts "Validation complete. Found #{missing_departments.size} references to non-existent departments."

        # Group by missing segments for a more organized report
        by_missing_segment = missing_departments.group_by { |item| item[:missing_segment] }
        puts 'Missing department report:'

        by_missing_segment.each do |segment, occurrences|
          referencing_depts = occurrences.map { |o| o[:parent_id] }
          puts "  '#{segment}' is referenced by: #{referencing_depts.join(', ')}"
        end
      end

      if missing_departments.present? || invalid_term || duplicate_ids.present?
        raise 'Department vocabulary failed validation'
      end
    end
  end
end
