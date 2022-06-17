require 'time'

module Tasks
  # Service for reindexing objects from one solr instance to another
  class SolrMigrationService
    PAGE_SIZE = 1000
    WORK_TYPES = 'Article Artwork DataSet Dissertation General HonorsThesis Journal MastersPaper Multimed ScholarlyWork'
    FILESET_TYPES = 'FileSet'
    ADMINSET_TYPES = 'AdminSet'
    COLLECTION_TYPES = 'Collection'
    HYDRA_TYPES = 'Hydra*'
    AF_TYPES = 'ActiveFedora*'
    OTHER_TYPES = 'DepositRecord FedoraOnlyFile'
    # Types in the order they should be listed
    QUERY_TYPE_LIST = [ADMINSET_TYPES, COLLECTION_TYPES, WORK_TYPES, FILESET_TYPES, OTHER_TYPES, HYDRA_TYPES, AF_TYPES]

    # List all object ids in the repository, ordered by object type.
    # Returns the path to the file containing the list of ids. Its name contains the timestamp when the command was issued.
    def list_object_ids(output_path, after_timestamp = nil)
      # Capture current time in UTC, as snapshot of starting point for ids
      start_time = (Time.now - 1).utc.iso8601.gsub!(/:/, '_')
      # Start list file for IDs, in file named with starting point timestamp
      filename = "id_list_#{start_time}.txt"
      file_path = File.join(output_path, filename)
      File.open(file_path, 'w') do |file|
        QUERY_TYPE_LIST.each do |query_types|
          record_paged_type_query(file, query_types)
        end
      end
      return file_path
    end

    def record_paged_type_query(file, query_types)
      start_row = 0
      total_count = 0
      begin
        resp = ActiveFedora::SolrService.get("has_model_ssim:(#{query_types})",
                                             sort: 'system_create_dtsi ASC',
                                             start: start_row,
                                             rows: PAGE_SIZE,
                                             fl: 'id')['response']
        total_count = resp['numFound'].to_i
        resp['docs'].each do |doc|
          file.puts(doc['id'])
        end
        start_row += PAGE_SIZE
      end while docs.length == PAGE_SIZE && (start_row + PAGE_SIZE) < total_count
    end

    # Trigger indexing of all objects listed in the provided file
    def reindex(id_list_file)
      # Read input file
      id_file = File.new(id_list_file)
      id_file.each_line do |line|

      end
    end
  end
end