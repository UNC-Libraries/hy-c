# frozen_string_literal: true

require 'csv'

Bulkrax:: CsvParser.class_eval do
  # [hyc-override] file permissions update from 0600 to 0644
  # This method comes from application_parser.rb
  alias_method :original_write_import_file, :write_import_file
  def write_import_file(file)
    path = original_write_import_file(file)

    FileUtils.chmod(owner_write_and_global_read_file_permissions, path)

    path
  end

  def valid_import?
    compressed_record = records.flat_map(&:to_a).partition { |_, v| !v }.flatten(1).to_h
    error_alert = "Missing at least one required element, missing element(s) are: #{missing_elements(compressed_record).join(', ')}"
    raise StandardError, error_alert unless required_elements?(compressed_record)
    # [hyc-override] explicitly raise error when file paths are not present
    raise StandardError.new 'file paths are invalid' unless file_paths.is_a?(Array)
    true
  rescue StandardError => e
    status_info(e)
    false
  end

  # [hyc-override] change file permissions
  alias_method :original_write_partial_import_file, :write_partial_import_file
  def write_partial_import_file(file)
    path = original_write_partial_import_file(file)
    FileUtils.chmod(owner_write_and_global_read_file_permissions, path)
    path
  end

  private

  def owner_write_and_global_read_file_permissions
    0644
  end
end
