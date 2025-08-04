# frozen_string_literal: true
class Tasks::PubmedIngest::SharedUtilities::IngestTracker
  TRACKER_FILENAME = 'ingest_tracker.json'
  attr_reader :path, :data

  def self.build(config:, resume: false)
    output_dir = config['output_dir']
    path = File.join(output_dir, 'ingest_tracker.json')

    if resume
      LogUtilsHelper.double_log('Resume flag is set. Attempting to resume PubMed ingest from previous state.', :info, tag: 'Ingest Tracker')
      instance = new(output_dir, config)
      instance['restart_time'] = config['restart_time'].strftime('%Y-%m-%d %H:%M:%S')
      LogUtilsHelper.double_log("Resuming from existing state: #{instance.data}", :info, tag: 'Ingest Tracker')
      return instance
    end

    if File.exist?(path) &&
      LogUtilsHelper.double_log("Tracker file already exists at #{path}.", :error, tag: 'Ingest Tracker')
      exit(1)
    end

    LogUtilsHelper.double_log('Resume flag is not set. Initializing new ingest tracker.', :info, tag: 'Ingest Tracker')
    instance = new(output_dir, config)
    instance.save
    instance
  end

  def initialize(output_dir, config)
    @path = File.join(output_dir, 'ingest_tracker.json')
    @data = File.exist?(@path) ? load_tracker_file : build_initial_tracker(config)
  end

  def [](key)
    @data[key]
  end

  def []=(key, value)
    @data[key] = value
  end

  def save
    File.open(@path, 'w', encoding: 'utf-8') { |f| f.puts(JSON.pretty_generate(@data)) }
  rescue => e
    LogUtilsHelper.double_log("Failed to save ingest tracker: #{e.message}", :error, tag: 'Ingest Tracker')
  end

        private

  def load_tracker_file
    LogUtilsHelper.double_log("Found existing ingest tracker at #{@path}. Loading data.", :info, tag: 'Ingest Tracker')
    content = File.read(@path, encoding: 'utf-8')
    JSON.parse(content)
  rescue => e
    LogUtilsHelper.double_log("Failed to load ingest tracker: #{e.message}", :error, tag: 'Ingest Tracker')
    {}
  end

  def build_initial_tracker(config)
    LogUtilsHelper.double_log("Building initial ingest tracker with config: #{config}", :info, tag: 'Ingest Tracker')
    {
      'start_time' => config['time'].strftime('%Y-%m-%d %H:%M:%S'),
      'restart_time' => nil,
      'date_range' => {
        'start' => config['start_date'].strftime('%Y-%m-%d'),
        'end' => config['end_date'].strftime('%Y-%m-%d')
      },
      'admin_set_title' => config['admin_set_title'],
      'depositor_onyen' => config['depositor_onyen'],
      'output_dir' => config['output_dir'],
      'full_text_dir' => config['full_text_dir'],
      'progress' => {
        'retrieve_ids_within_date_range' => {
            'pubmed' => { 'cursor' => 0, 'completed' => false },
            'pmc' => { 'cursor' => 0, 'completed' => false }
        },
        'stream_and_write_alternate_ids' => {
            'pubmed' => { 'cursor' => 0, 'completed' => false },
            'pmc' => { 'cursor' => 0, 'completed' => false }
        },
        'adjust_id_lists' => {
            'completed' => false,
            'pubmed' => { 'original_size' => 0, 'adjusted_size' => 0 },
            'pmc' => { 'original_size' => 0, 'adjusted_size' => 0 }
        },
        'metadata_ingest' => {
            'pubmed' => { 'cursor' => 0, 'result_index' => 0, 'completed' => false },
            'pmc' => { 'cursor' => 0, 'result_index' => 0, 'completed' => false }
        },
        'attach_files_to_works' => {
            'completed' => false,
            'cursor' => 0,
            'result_index' => 0
        }}
    }
  end
end
