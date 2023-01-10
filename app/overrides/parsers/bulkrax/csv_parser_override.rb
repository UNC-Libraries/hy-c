# frozen_string_literal: true

# [hyc-override] overriding application_parser `write_import_files` and `unzip` methods
# [hyc-override] raise errors in `valid_import?` method
require 'csv'

Bulkrax:: CsvParser.class_eval do
  # overriding to include file permissions update from 0600 to 0644
  # This method comes from application_parser.rb
  def write_import_file(file)
    path = File.join(path_for_import, file.original_filename)
    FileUtils.mv(
      file.path,
      path
    )
    FileUtils.chmod(owner_write_and_global_read_file_permissions, path)

    if MIME::Types.type_for(path).include?('application/zip')
      unzip(path, path_for_import)

      Dir.glob("#{path_for_import}/files/*").each do |attached_file|
        FileUtils.chmod(owner_write_and_global_read_file_permissions, attached_file)
      end

      Dir["#{path_for_import}/*.csv"].first
    else
      path
    end
  end

  # overriding to provide unzip location
  def unzip(file_to_unzip, unzip_path)
    Zip::File.open(file_to_unzip) do |zip_file|
      zip_file.each do |entry|
        entry_path = File.join(unzip_path, entry.name)
        FileUtils.mkdir_p(File.dirname(entry_path))
        zip_file.extract(entry, entry_path) unless File.exist?(entry_path)
      end
    end
  end

  def valid_import?
    import_strings = keys_without_numbers(import_fields.map(&:to_s))
    error_alert = "Missing at least one required element, missing element(s) are: #{missing_elements(import_strings).join(', ')}"
    raise StandardError, error_alert unless required_elements?(import_strings)
    raise StandardError.new 'file paths are invalid' unless file_paths.is_a?(Array)
    true
  rescue StandardError => e
    status_info(e)
    false
  end

  # Overriding method to change file permissions
  def write_partial_import_file(file)
    import_filename = import_file_path.split('/').last
    partial_import_filename = "#{File.basename(import_filename, '.csv')}_corrected_entries.csv"

    path = File.join(path_for_import, partial_import_filename)
    FileUtils.mv(
      file.path,
      path
    )
    FileUtils.chmod(0644, path)
    path
  end

  def set_ids_for_exporting_from_importer
    entry_ids = Bulkrax::Importer.find(importerexporter.export_source).entries.pluck(:id)
    complete_statuses = Bulkrax::Status.latest_by_statusable
                              .includes(:statusable)
                              .where('bulkrax_statuses.statusable_id IN (?) AND bulkrax_statuses.statusable_type = ? AND status_message = ?', entry_ids, 'Bulkrax::Entry', 'Complete')

    complete_entry_identifiers = complete_statuses.map { |s| s.statusable&.identifier&.gsub(':', '\:') }
    extra_filters = extra_filters.presence || '*:*'

    { :@work_ids => ::Hyrax.config.curation_concerns, :@collection_ids => [::Collection], :@file_set_ids => [::FileSet] }.each do |instance_var, models_to_search|
      instance_variable_set(instance_var, ActiveFedora::SolrService.post(
        extra_filters.to_s,
        fq: [
          # [hyc-override] Replacing Solrizer reference with direct id field reference
          %(id:("#{complete_entry_identifiers.join('" OR "')}")),
          "has_model_ssim:(#{models_to_search.join(' OR ')})"
        ],
        fl: 'id',
        rows: 2_000_000_000
      )['response']['docs'].map { |obj| obj['id'] })
    end
  end

  private

  def owner_write_and_global_read_file_permissions
    0644
  end
end
