require 'time'
require 'ruby-progressbar'

module Tasks
  # Service for reindexing objects from one solr instance to another
  class SolrMigrationService
    PAGE_SIZE = 1000

    # List all object ids in the repository, ordered by object type.
    # Returns the path to the file containing the list of ids. Its name contains the timestamp when the command was issued.
    def list_object_ids(output_path, after_timestamp = nil)
      # Capture current time in UTC, as snapshot of starting point for ids
      start_time = (Time.now - 1).utc.iso8601.gsub!(/:/, '_')
      # Start list file for IDs, in file named with starting point timestamp
      filename = "id_list_#{start_time}.txt"
      file_path = File.join(output_path, filename)
      File.open(file_path, 'w') do |file|
        record_paged_type_query(file, nil)
      end
      return file_path
    end

    def record_paged_type_query(file, query_types)
      start_row = 0
      total_count = 0
      begin
        resp = ActiveFedora::SolrService.get("*:*",
                                             sort: 'system_create_dtsi ASC',
                                             start: start_row,
                                             rows: PAGE_SIZE,
                                             fl: 'id')['response']
        total_count = resp['numFound'].to_i
        resp['docs'].each do |doc|
          file.puts(doc['id'])
        end
        start_row += PAGE_SIZE
      end while resp['docs'].length == PAGE_SIZE && (start_row + PAGE_SIZE) < total_count
    end

    # Trigger indexing of all objects listed in the provided file
    def reindex(id_list_file, clean_index)
      id_total = File.foreach(id_list_file).inject(0) {|c, line| c+1}

      progress_logger = Migrate::Services::ProgressTracker.new(progress_log_path(id_list_file))
      if clean_index
        puts "**** Clearing index ****"
        Blacklight.default_index.connection.delete_by_query('*:*')
        Blacklight.default_index.connection.commit
      end

      progressbar = ProgressBar.create(:total => id_total,
          :length => 80,
          :format => "%E |%b\u{15E7}%i| %p%% (%c / %C \u{0394}%R)",
          :progress_mark => ' ',
          :remainder_mark => "\u{FF65}")

      # Read input file
      id_file = File.new(id_list_file)
      id_file.each_line do |id_line|
        id = id_line.chomp
        object = ActiveFedora::Base.find(id)
        # Must use update_index instead of going to SolrService.add in order to trigger NestingCollection behaviors
        object.update_index
        progressbar.increment
        progress_logger.add_entry(id)
      end
    end

    def progress_log_path(id_list_file)
      "#{id_list_file}-progress.log"
    end
  end
end