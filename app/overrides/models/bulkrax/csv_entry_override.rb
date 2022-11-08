# frozen_string_literal: true

require 'csv'

# [hyc-override] overriding build_export_metadata method
# [hyc-override] check model name before building entry
Bulkrax::CsvEntry.class_eval do
  def build_metadata
    raise StandardError, 'Record not found' if record.nil?
    raise StandardError, "Missing required elements, missing element(s) are: #{importerexporter.parser.missing_elements(keys_without_numbers(record.keys)).join(', ')}" unless importerexporter.parser.required_elements?(keys_without_numbers(record.keys))

    raise StandardError.new "uninitialized constant #{record['model']} (NameError)" unless record['model'].nil? || work_types.include?(record['model'])

    self.parsed_metadata = {}
    add_identifier
    add_ingested_metadata
    # TODO(alishaevn): remove the collections stuff entirely and only reference collections via the new parents code
    add_collections
    add_visibility
    add_metadata_for_model
    add_rights_statement
    sanitize_controlled_uri_values!
    add_local

    self.parsed_metadata
  end

  def work_types
    %w[Article Artwork DataSet Dissertation General HonorsThesis Journal MastersPaper Multimed ScholarlyWork]
  end
end
