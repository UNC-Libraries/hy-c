# frozen_string_literal: true
# [hyc-override] overriding `write_files`,`export_headers`, `write_partial_import`,
# and `real_import_file_path` methods and adding `people_types` method
# [hyc-override] overriding application_parser `write_import_files` and `unzip` methods
# [hyc-override] raise errors in `valid_import?` method

require 'csv'
module Bulkrax
  class CsvParser < ApplicationParser
    def self.export_supported?
      true
    end

    def initialize(importerexporter)
      @importerexporter = importerexporter
    end

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

    def collections
      # does the CSV contain a collection column?
      return [] unless import_fields.include?(:collection)
      # retrieve a list of unique collections
      records.map { |r| r[:collection].split(/\s*[;|]\s*/) unless r[:collection].blank? }.flatten.compact.uniq
    end

    def collections_total
      collections.size
    end

    def records(_opts = {})
      file_for_import = only_updates ? parser_fields['partial_import_file_path'] : import_file_path
      @records ||= entry_class.read_data(file_for_import).map { |record_data| entry_class.data_for_entry(record_data) }
    end

    # We could use CsvEntry#fields_from_data(data) but that would mean re-reading the data
    def import_fields
      @import_fields ||= records.inject(:merge).keys.compact.uniq
    end

    def required_elements?(keys)
      return if keys.blank?
      !required_elements.map { |el| keys.map(&:to_s).include?(el) }.include?(false)
    end

    def required_elements
      %w[title source_identifier]
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

    def create_collections
      collections.each_with_index do |collection, index|
        next if collection.blank?
        metadata = {
            title: [collection],
            Bulkrax.system_identifier_field => [collection],
            visibility: 'open',
            collection_type_gid: Hyrax::CollectionType.find_or_create_default_collection_type.gid
        }
        new_entry = find_or_create_entry(collection_entry_class, collection, 'Bulkrax::Importer', metadata)
        ImportWorkCollectionJob.perform_now(new_entry.id, current_importer_run.id)
        increment_counters(index, true)
      end
    end

    def create_works
      records.each_with_index do |record, index|
        if record[:source_identifier].blank?
          current_importer_run.invalid_records ||= ""
          current_importer_run.invalid_records += "Missing #{Bulkrax.system_identifier_field} for #{record.to_h}\n"
          current_importer_run.failed_records += 1
          current_importer_run.save
          next
        end
        break if limit_reached?(limit, index)

        seen[record[:source_identifier]] = true
        new_entry = find_or_create_entry(entry_class, record[:source_identifier], 'Bulkrax::Importer', record.to_h.compact)
        if record[:delete].present?
          DeleteWorkJob.send(perform_method, new_entry, current_importer_run)
        else
          ImportWorkJob.send(perform_method, new_entry.id, current_importer_run.id)
        end
        increment_counters(index)
      end
      status_info
    rescue StandardError => e
      status_info(e)
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

    def create_parent_child_relationships
      super
    end

    def create_from_importer
      importer = Bulkrax::Importer.find(importerexporter.export_source)
      non_errored_entries = importer.entries.where(type: importer.parser.entry_class.to_s, last_error: [nil, {}, ''])
      non_errored_entries.each_with_index do |entry, index|
        break if limit_reached?(limit, index)
        query = "#{ActiveFedora.index_field_mapper.solr_name(Bulkrax.system_identifier_field)}:\"#{entry.identifier}\""
        work_id = ActiveFedora::SolrService.query(query, fl: 'id', rows: 1).first['id']
        new_entry = find_or_create_entry(entry_class, work_id, 'Bulkrax::Exporter')
        Bulkrax::ExportWorkJob.perform_now(new_entry.id, current_exporter_run.id)
      end
    end

    def create_from_collection
      work_ids = ActiveFedora::SolrService.query("member_of_collection_ids_ssim:#{importerexporter.export_source}").map(&:id)
      work_ids.each_with_index do |wid, index|
        break if limit_reached?(limit, index)
        new_entry = find_or_create_entry(entry_class, wid, 'Bulkrax::Exporter')
        Bulkrax::ExportWorkJob.perform_now(new_entry.id, current_exporter_run.id)
      end
    end

    def create_from_worktype
      work_ids = ActiveFedora::SolrService.query("has_model_ssim:#{importerexporter.export_source}").map(&:id)
      work_ids.each_with_index do |wid, index|
        break if limit_reached?(limit, index)
        new_entry = find_or_create_entry(entry_class, wid, 'Bulkrax::Exporter')
        Bulkrax::ExportWorkJob.perform_now(new_entry.id, current_exporter_run.id)
      end
    end

    def entry_class
      CsvEntry
    end

    def collection_entry_class
      CsvCollectionEntry
    end

    # See https://stackoverflow.com/questions/2650517/count-the-number-of-lines-in-a-file-without-reading-entire-file-into-memory
    #   Changed to grep as wc -l counts blank lines, and ignores the final unescaped line (which may or may not contain data)
    def total
      if importer?
        # @total ||= `wc -l #{parser_fields['import_file_path']}`.to_i - 1
        @total ||= `grep -vc ^$ #{parser_fields['import_file_path']}`.to_i - 1
      elsif exporter?
        @total ||= importerexporter.entries.count
      else
        @total = 0
      end
    rescue StandardError
      @total = 0
    end

    # @todo - investigate getting directory structure
    # @todo - investigate using perform_later, and having the importer check for
    #   DownloadCloudFileJob before it starts
    def retrieve_cloud_files(files)
      files_path = File.join(path_for_import, 'files')
      FileUtils.mkdir_p(files_path) unless File.exist?(files_path)
      files.each_pair do |_key, file|
        # fixes bug where auth headers do not get attached properly
        if file['auth_header'].present?
          file['headers'] ||= {}
          file['headers'].merge!(file['auth_header'])
        end
        # this only works for uniquely named files
        target_file = File.join(files_path, file['file_name'].tr(' ', '_'))
        # Now because we want the files in place before the importer runs
        # Problematic for a large upload
        Bulkrax::DownloadCloudFileJob.perform_now(file, target_file)
      end
      return nil
    end

    # export methods

    # overriding to correctly export people attributes
    def write_files
      CSV.open(setup_export_file, "w", headers: export_headers, write_headers: true) do |csv|
        importerexporter.entries.each do |e|
          metadata = e.parsed_metadata
          # get people metadata
          work_record = ActiveFedora::Base.find(metadata['source_identifier'])
          # create hash of people attributes
          people_types.each do |person_type|
            metadata[person_type] = nil
            metadata["#{person_type}_attributes"] = nil
            if work_record.has_attribute?(person_type)
              person_hash = Hash.new
              work_record[person_type].each_with_index do |person_object, index|
                person_hash[index.to_s] = person_object.as_json
              end
              if person_hash.blank?
                metadata["#{person_type}_attributes"] = nil
              else
                metadata["#{person_type}_attributes"] = person_hash
              end
            end
          end
          csv << metadata
        end
      end
    end

    # overriding to add columns for people attributes and rename source column
    # if reimporting, there needs to be a source_identifier column
    def export_headers
      headers = ['id']
      headers << entry_class.source_identifier_field
      headers << 'model'
      importerexporter.mapping.each_key { |key| headers << key unless Bulkrax.reserved_properties.include?(key) && !field_supported?(key) }.sort
      headers << 'file'
      people_types.each { |key| headers << "#{key}_attributes" }
      headers
    end

    # in the parser as it is specific to the format
    def setup_export_file
      File.join(importerexporter.exporter_export_path, 'export.csv')
    end

    # Retrieve file paths for [:file] in records
    #  and check all listed files exist.
    def file_paths
      raise StandardError, 'No records were found' if records.blank?
      @file_paths ||= records.map do |r|
        next unless r[:file].present?
        r[:file].split(/\s*[:;|]\s*/).map do |f|
          file = File.join(path_to_files, f.tr(' ', '_'))
          if File.exist?(file) # rubocop:disable Style/GuardClause
            file
          else
            raise "File #{file} does not exist"
          end
        end
      end.flatten.compact.uniq
    end

    # Retrieve the path where we expect to find the files
    def path_to_files
      @path_to_files ||= File.join(
          File.file?(import_file_path) ? File.dirname(import_file_path) : import_file_path,
          'files'
      )
    end

    # errored entries methods

    def write_errored_entries_file
      @errored_entries ||= importerexporter.entries.where.not(last_error: [nil, {}, ''], type: 'Bulkrax::CsvCollectionEntry')
      return unless @errored_entries.present?

      file = setup_errored_entries_file
      headers = import_fields
      file.puts(headers.to_csv)
      @errored_entries.each do |ee|
        row = build_errored_entry_row(headers, ee)
        file.puts(row)
      end
      file.close
      true
    end

    def build_errored_entry_row(headers, errored_entry)
      row = {}
      # Ensure each header has a value, even if it's just an empty string
      headers.each do |h|
        row.merge!("#{h}": nil)
      end
      # Match each value to its corresponding header
      row.merge!(errored_entry.raw_metadata.symbolize_keys)

      row.values.to_csv
    end

    def setup_errored_entries_file
      File.open(importerexporter.errored_entries_csv_path, 'w')
    end

    private

    # Override to return the first CSV in the path, if a zip file is supplied
    # We expect a single CSV at the top level of the zip in the CSVParser
    def real_import_file_path
      if file? && zip?
        unzip(parser_fields['import_file_path'], importer_unzip_path)
        return Dir["#{importer_unzip_path}/*.csv"].first
      else
        parser_fields['import_file_path']
      end
    end

    # overriding to add array of people types
    def people_types
      ['advisors', 'arrangers', 'composers', 'contributors', 'creators', 'project_directors', 'researchers',
       'reviewers', 'translators']
    end

    def owner_write_and_global_read_file_permissions
      0644
    end
  end
end
