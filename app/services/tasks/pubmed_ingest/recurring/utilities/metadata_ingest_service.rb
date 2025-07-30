# frozen_string_literal: true
class Tasks::PubmedIngest::Recurring::Utilities::MetadataIngestService
  def initialize(config:, results_tracker:)
    @output_dir = config['output_dir']
    @record_ids = nil
    @results_tracker = results_tracker
  end

  def load_ids_from_file(path:)
    @record_ids = File.readlines(path).map { |line| JSON.parse(line) }.compact
  end

  def batch_retrieve_and_process_metadata(batch_size: 100, db:)
    unless SharedUtilities::DbType.valid?(db)
      raise ArgumentError, "Invalid database type: #{db}. Valid types are: #{SharedUtilities::DbType::ALL.join(', ')}"
    end
    
    return if @record_ids.nil? || @record_ids.empty?
      # WIP: Print the number of records to be processed
    puts "Processing #{@record_ids.size} records in batches of #{batch_size}."
  end

end
