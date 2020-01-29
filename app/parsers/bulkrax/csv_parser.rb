# frozen_string_literal: true
# [hyc-override] overriding `write_files` and `export_headers` methods and adding `people_types` method

require 'csv'
module Bulkrax
  class CsvParser < ApplicationParser
    def self.export_supported?
      true
    end

    def initialize(importerexporter)
      @importerexporter = importerexporter
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
      @records ||= entry_class.read_data(parser_fields['import_file_path']).map { |record_data| entry_class.data_for_entry(record_data) }
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
      required_elements?(import_fields) && file_paths.is_a?(Array)
    rescue StandardError => e
      errors.add(:base, e.class.to_s.to_sym, message: e.message)
      return false
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
        next if record[:source_identifier].blank?
        break if !limit.nil? && index >= limit

        seen[record[:source_identifier]] = true
        new_entry = find_or_create_entry(entry_class, record[:source_identifier], 'Bulkrax::Importer', record.to_h.compact)
        ImportWorkJob.perform_later(new_entry.id, current_importer_run.id)
        increment_counters(index)
      end
    rescue StandardError => e
      errors.add(:base, e.class.to_s.to_sym, message: e.message)
    end

    def create_parent_child_relationships
      super
    end

    def create_from_importer
      Bulkrax::Importer.find(importerexporter.export_source).entries.each do |entry|
        query = "#{ActiveFedora.index_field_mapper.solr_name(Bulkrax.system_identifier_field)}:\"#{entry.identifier}\""
        work_id = ActiveFedora::SolrService.query(query, fl: 'id', rows: 1).first['id']
        new_entry = find_or_create_entry(entry_class, work_id, 'Bulkrax::Exporter')
        Bulkrax::ExportWorkJob.perform_now(new_entry.id, current_exporter_run.id)
      end
    end

    def create_from_collection
      work_ids = ActiveFedora::SolrService.query("member_of_collection_ids_ssim:#{importerexporter.export_source}").map(&:id)
      work_ids.each do |wid|
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
      file = setup_export_file
      file.puts(export_headers)
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

        file.puts(metadata.values.to_csv)
      end
      file.close
    end

    # overriding to add columns for people attributes and rename source column
    # if reimporting, there needs to be a source_identifier column
    def export_headers
      headers = ['id']
      headers << 'model'
      importerexporter.mapping.keys.each { |key| headers << key unless Bulkrax.reserved_properties.include?(key) && !field_supported?(key) }.sort
      headers.map!{|key| key == 'source' ? 'source_identifier' : key}
      headers << 'file'
      people_types.each { |key| headers << "#{key}_attributes" }
      headers.to_csv
    end

    # in the parser as it is specific to the format
    def setup_export_file
      File.open(File.join(importerexporter.exporter_export_path, 'export.csv'), 'w')
    end

    def file_paths
      @file_paths ||= records.map do |r|
        next unless r[:file].present?
        r[:file].split(/\s*[:;|]\s*/).map do |f|
          file = File.join(files_path, f.tr(' ', '_'))
          if File.exist?(file)
            file
          else
            raise "File #{file} does not exist"
          end
        end
      end.flatten.compact.uniq
    end

    def files_path
      path = self.importerexporter.parser_fields['import_file_path'].split('/')
      # remove the metadata filename from the end of the import path
      path.pop
      File.join(path.join('/'), 'files')
    end

    # overriding to add array of people types
    def people_types
      ['advisors', 'arrangers', 'composers', 'contributors', 'creators', 'project_directors', 'researchers',
       'reviewers', 'translators']
    end
  end
end
