# frozen_string_literal: true
# [hyc-override] check model name before building entry
# https://github.com/samvera-labs/bulkrax/blob/v4.4.0/app/models/bulkrax/csv_entry.rb
Bulkrax::CsvEntry.class_eval do
  WORK_TYPES ||= %w[Article Artwork DataSet Dissertation General HonorsThesis Journal MastersPaper Multimed ScholarlyWork FileSet Collection]

  alias_method :original_build_metadata, :build_metadata
  def build_metadata
    raise StandardError.new "uninitialized constant #{record['model']} (NameError)" if invalid_model_type(record)
    original_build_metadata
  end

  def invalid_model_type(record)
    return false if record.nil?
    record['model'].nil? || !WORK_TYPES.include?(record['model'])
  end
end
