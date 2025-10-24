# frozen_string_literal: true
class Tasks::IngestHelperUtils::BaseIngestTracker
  TRACKER_FILENAME = 'ingest_tracker.json'
  attr_reader :path, :data

  def self.build(config:, resume: false)
    output_dir = config['output_dir']
    path = File.join(output_dir, TRACKER_FILENAME)

    instance = new(output_dir, config)

    if resume && File.exist?(path)
      instance.resume!(config)
    else
      instance.initialize_new!(config)
    end
    instance.save
    instance
  end

  def initialize(config)
    @path = File.join(config['output_dir'], TRACKER_FILENAME)
    @data = {}
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

  def resume!(config)
    LogUtilsHelper.double_log('Resuming ingest from previous tracker state.', :info, tag: self.class.name)
    @data = load_tracker_file
    @data['restart_time'] = config['restart_time']&.strftime('%Y-%m-%d %H:%M:%S')
    @data
  end

  def initialize_new!(config)
    LogUtilsHelper.double_log('Initializing new ingest tracker.', :info, tag: self.class.name)
    @data = build_base_tracker(config)
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

  def build_base_tracker(config)
    {
        'start_time' => config['time']&.strftime('%Y-%m-%d %H:%M:%S'),
        'restart_time' => config['restart_time']&.strftime('%Y-%m-%d %H:%M:%S'),
        'date_range' => {
        'start' => config['start_date']&.strftime('%Y-%m-%d'),
        'end' => config['end_date']&.strftime('%Y-%m-%d')
        },
        'admin_set_title' => config['admin_set_title'],
        'depositor_onyen' => config['depositor_onyen'],
        'output_dir' => config['output_dir'],
        'full_text_dir' => config['full_text_dir'],
        'progress' => {}
    }
  end
end
