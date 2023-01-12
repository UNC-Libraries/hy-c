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
    import_strings = keys_without_numbers(import_fields.map(&:to_s))
    error_alert = "Missing at least one required element, missing element(s) are: #{missing_elements(import_strings).join(', ')}"
    raise StandardError, error_alert unless required_elements?(import_strings)
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
          # [hyc-override] Replacing Solrizer reference
          %(#{::ActiveFedora.index_field_mapper.solr_name(work_identifier)}:("#{complete_entry_identifiers.join('" OR "')}")),
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
