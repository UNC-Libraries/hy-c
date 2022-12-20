# frozen_string_literal: true

# [hyc-override] overriding `write_files`,`export_headers`, `write_partial_import`,
# and `real_import_file_path` methods and adding `people_types` method
# [hyc-override] overriding application_parser `write_import_files` and `unzip` methods
# [hyc-override] raise errors in `valid_import?` method
# [hyc-override] Set source_identifier to string if an Array and set it to work id if empty
# [hyc-override] Fix bug in current_work_ids
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

  # export methods
  # overriding to correctly export people attributes
  # overriding to set source_identifier to string if an Array and set it to work id if empty
  def write_files
    require 'open-uri'
    folder_count = 0
    sorted_entries = sort_entries(importerexporter.entries.uniq(&:identifier))
                       .select { |e| valid_entry_types.include?(e.type) }

    sorted_entries[0..limit || total].in_groups_of(records_split_count, false) do |group|
      folder_count += 1

      CSV.open(setup_export_file(folder_count), 'w', headers: export_headers, write_headers: true) do |csv|
        group.each do |entry|
          metadata = entry.parsed_metadata
          metadata['source_identifier'] = metadata['id'] if metadata['source_identifier'].blank?
          metadata['source_identifier'] = metadata['source_identifier'].join(', ') if metadata['source_identifier'].is_a?(Array)

          # get people metadata
          work_record = ActiveFedora::Base.find(metadata['id'])
          # create hash of people attributes
          people_types.each do |person_type|
            metadata[person_type] = nil
            metadata["#{person_type}_attributes"] = nil
            if work_record.has_attribute?(person_type)
              person_hash = Hash.new
              work_record[person_type].each_with_index do |person_object, index|
                person_hash[index.to_s] = person_object.as_json
              end
              metadata["#{person_type}_attributes"] = if person_hash.blank?
                                                        nil
                                                      else
                                                        person_hash
                                                      end
            end
          end

          csv << metadata
          next if importerexporter.metadata_only? || entry.type == 'Bulkrax::CsvCollectionEntry'

          store_files(entry.identifier, folder_count.to_s)
        end
      end
    end

    sorted_entries
  end

  # overriding to add columns for people attributes
  # if reimporting, there needs to be a source_identifier column
  def export_headers
    headers = sort_headers(self.headers)

    # we don't want access_control_id exported and we want file at the end
    headers.delete('access_control_id') if headers.include?('access_control_id')

    # add the headers below at the beginning or end to maintain the preexisting export behavior
    headers.prepend('model')
    headers.prepend(source_identifier.to_s)
    headers.prepend('id')
    people_types.each { |key| headers << "#{key}_attributes" }

    headers.uniq
  end

  private

  # overriding to add array of people types
  def people_types
    %w[advisors arrangers composers contributors creators project_directors researchers reviewers translators]
  end

  def owner_write_and_global_read_file_permissions
    0644
  end
end
