# frozen_string_literal: true

# [hyc-override] overriding `write_files`,`export_headers`, `write_partial_import`,
# and `real_import_file_path` methods and adding `people_types` method
# [hyc-override] overriding application_parser `write_import_files` and `unzip` methods
# [hyc-override] raise errors in `valid_import?` method
# [hyc-override] Set source_identifier to string if an Array and set it to work id if empty
require 'csv'

Bulkrax:: CsvParser.class_eval do
  # overriding to include file permissions update from 0600 to 0644
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
    WillowSword::ZipPackage.new(file_to_unzip, unzip_path).unzip_file
  end

  def valid_import?
    required_fields = required_elements?(import_fields)
    file_path_array = file_paths.is_a?(Array)
    if !required_fields
      raise StandardError.new "missing required column: #{required_elements.join(' or ')}"
    elsif !file_path_array
      raise StandardError.new 'file paths are invalid'
    end

    required_elements?(import_fields) && file_paths.is_a?(Array)
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
    CSV.open(setup_export_file, 'w', headers: export_headers, write_headers: true) do |csv|
      importerexporter.entries.where(identifier: current_work_ids)[0..limit || total].each_with_index do |e, index|
        metadata = e.parsed_metadata

        metadata['source_identifier'] = metadata['id'] if metadata['source_identifier'].blank?

        metadata['source_identifier'] = metadata['source_identifier'].join(', ') if metadata['source_identifier'].is_a?(Array)

        # get people metadata
        work_record = ActiveFedora::Base.find(current_work_ids[index])
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
      end
    end
  end

  # overriding to add columns for people attributes
  # if reimporting, there needs to be a source_identifier column
  def export_headers
    headers = ['id']
    headers << source_identifier.to_s
    headers << 'model'
    importerexporter.mapping.each_key { |key| headers << key if key_allowed(key) }
    headers << 'file'
    people_types.each { |key| headers << "#{key}_attributes" }
    headers.uniq
  end

  private

  # Override to return the first CSV in the path, if a zip file is supplied
  # We expect a single CSV at the top level of the zip in the CSVParser
  def real_import_file_path
    if file? && zip?
      unzip(parser_fields['import_file_path'], importer_unzip_path)
      Dir["#{importer_unzip_path}/*.csv"].first
    else
      parser_fields['import_file_path']
    end
  end

  # overriding to add array of people types
  def people_types
    %w[advisors arrangers composers contributors creators project_directors researchers reviewers translators]
  end

  def owner_write_and_global_read_file_permissions
    0644
  end
end
