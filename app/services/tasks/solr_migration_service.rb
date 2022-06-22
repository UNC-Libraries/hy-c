require 'date'
require 'time'
require 'ruby-progressbar'

module Tasks
  # Service for reindexing objects from one solr instance to another
  class SolrMigrationService
    PAGE_SIZE = 1000

    # List all object ids in the repository, ordered by object type.
    # Returns the path to the file containing the list of ids. Its name contains the timestamp when the command was issued.
    def list_object_ids(output_path, after_timestamp = nil)
      # Capture time in UTC, as snapshot of starting point for ids
      # (back dated a minute to ensure no changes get lost between now and when the query executes)
      start_time = (Time.now - 60).utc.iso8601.gsub!(/:/, '_')
      # Start list file for IDs, in file named with starting point timestamp
      filename = "id_list_#{start_time}.txt"
      file_path = File.join(output_path, filename)
      File.open(file_path, 'w') do |file|
        record_paged_type_query(file, after_timestamp)
      end
      return file_path
    end

    def record_paged_type_query(file, after_timestamp)
      start_row = 0
      total_count = 0
      if after_timestamp.nil?
        query = "*:*"
      else
        # Replace underscores with :'s since that is the format used in the list filenames
        after_timestamp.gsub!(/_/, ':')
        # Validate the timestamp is in iso8601 format
        begin
          DateTime.iso8601(after_timestamp)
        rescue
          raise ArgumentError.new("Invalid after timestamp, must be in ISO8601 format but was #{after_timestamp}")
        end
        query = "system_modified_dtsi:[#{after_timestamp} TO *]"
      end
      puts "Running query: #{query}"
      begin
        resp = ActiveFedora::SolrService.get(query,
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
      # count the number of lines in the file to get the total number of ids being indexed for presenting progress
      id_total = File.foreach(id_list_file).inject(0) {|c, line| c+1}

      # Start or resume from progress log, which is a sidecar file based off the id list.
      # For example, /tmp/id_list_2022-06-21T19_55_08Z.txt logs progress to /tmp/id_list_2022-06-21T19_55_08Z.txt-progress.log
      progress_file = progress_log_path(id_list_file)
      progress_tracker = Migrate::Services::ProgressTracker.new(progress_file)
      completed = progress_tracker.completed_set
      resuming = false

      if !completed.empty?
        puts "**** Resuming reindexing, #{completed.length} previously completed ****"
        resuming = true
      end
      if clean_index
        if resuming
          raise ArgumentError.new("Cannot request clean index when resuming. To start over, delete the progress log at #{progress_file}")
        end
        puts "**** Clearing index ****"
        Blacklight.default_index.connection.delete_by_query('*:*')
        Blacklight.default_index.connection.commit
      end

      progressbar = ProgressBar.create(:total => id_total,
          :starting_at => completed.length,
          :length => 80,
          :format => "%E |%b\u{15E7}%i| %p%% (%c / %C \u{0394}%R)",
          :progress_mark => ' ',
          :remainder_mark => "\u{FF65}")

      # Read input file
      id_file = File.new(id_list_file)
      id_file.each_line do |id_line|
        id = id_line.chomp
        # skip id if it has previously been indexed
        next if resuming && completed.include?(id)

        object = ActiveFedora::Base.find(id)
        # Must use update_index instead of going to SolrService.add in order to trigger NestingCollection behaviors
        object.update_index
        progressbar.increment
        progress_tracker.add_entry(id)
      end
    end

    def progress_log_path(id_list_file)
      "#{id_list_file}-progress.log"
    end
  end
end