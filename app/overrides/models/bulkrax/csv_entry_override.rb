# frozen_string_literal: true

require 'csv'

Bulkrax::CsvEntry.class_eval do
  def build_metadata
    raise StandardError, 'Record not found' if record.nil?
    raise StandardError, "Missing required elements, missing element(s) are: #{importerexporter.parser.missing_elements(keys_without_numbers(record.keys)).join(', ')}" unless importerexporter.parser.required_elements?(keys_without_numbers(record.keys))

    raise StandardError.new "uninitialized constant #{record['model']} (NameError)" unless record['model'].nil? || work_types.include?(record['model'])

    self.parsed_metadata = {}
    self.parsed_metadata[work_identifier] = [record[source_identifier]]
    record.each do |key, value|
      next if key == 'collection'

      index = key[/\d+/].to_i - 1 if key[/\d+/].to_i != 0
      add_metadata(key_without_numbers(key), value, index)
    end

    add_file
    add_visibility
    add_rights_statement
    add_admin_set_id
    add_collections
    add_local
    self.parsed_metadata
  end

  # overriding to include all `mapping` keys in parsed metadata even when not supported by work type model
  # this fixes data mismatches in exports
  def build_export_metadata
    # make_round_trippable
    self.parsed_metadata = {}
    self.parsed_metadata['id'] = hyrax_record.id
    self.parsed_metadata[source_identifier] = hyrax_record.send(work_identifier)
    self.parsed_metadata['model'] = hyrax_record.has_model.first
    build_mapping_metadata
    unless hyrax_record.is_a?(Collection)
      self.parsed_metadata['file'] = hyrax_record.file_sets.map { |fs| filename(fs).to_s unless filename(fs).blank? }.compact.join('; ')
    end
    self.parsed_metadata
  end

  def work_types
    %w[Article Artwork DataSet Dissertation General HonorsThesis Journal MastersPaper Multimed ScholarlyWork]
  end
end
