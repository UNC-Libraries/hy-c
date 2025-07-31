# frozen_string_literal: true
module Tasks::PubmedIngest::SharedUtilities::TrackerHelper
  TRACKER_FILENAME = 'ingest_tracker.json'

  def self.init_tracker(config)
    json_path = File.join(config['output_dir'], TRACKER_FILENAME)
    tracker_data = {
      'start_time' => config['time'].strftime('%Y-%m-%d %H:%M:%S'),
      'restart_time' => nil,
      'date_range' => {
        'start' => config['start_date'].strftime('%Y-%m-%d'),
        'end' => config['end_date'].strftime('%Y-%m-%d')
      },
      'admin_set_title' => config['admin_set_title'],
      'depositor_onyen' => config['depositor_onyen'],
      'output_dir' => config['output_dir'],
      'progress' => nil
    }

    write_tracker_file(json_path, tracker_data)
    config.merge!(tracker_data)
  end

  def self.load_tracker(config)
    json_path = File.join(config['output_dir'], TRACKER_FILENAME)
    unless File.exist?(json_path)
      LogUtilsHelper.double_log("Ingest tracker JSON file not found: #{json_path}", :warn, tag: 'PubMed Ingest')
      return nil
    end

    begin
      content = File.read(json_path, encoding: 'utf-8')
      JSON.parse(content)
    rescue JSON::ParserError => e
      LogUtilsHelper.double_log("Failed to parse ingest tracker JSON: #{e.message}", :error, tag: 'PubMed Ingest')
      nil
    rescue => e
      LogUtilsHelper.double_log("Error reading ingest tracker: #{e.class} - #{e.message}", :error, tag: 'PubMed Ingest')
      nil
    end
  end

  def self.update_tracker(config, updates)
    json_path = File.join(config['output_dir'], TRACKER_FILENAME)
      # In-place deep merge into config
    deep_merge!(config, updates)
      # Write updated config to disk
    write_tracker_file(json_path, config)
    config
  end

  def self.deep_merge!(target, updates)
    updates.each do |key, value|
      if value.is_a?(Hash) && target[key].is_a?(Hash)
        deep_merge!(target[key], value)
      else
        target[key] = value
      end
    end
    target
  end

  def self.write_tracker_file(path, data)
    File.open(path, 'w', encoding: 'utf-8') do |file|
      file.puts(JSON.pretty_generate(data))
    end
  end

  def self.check_tracker_overwrite!(config, force_overwrite: false)
    tracker_path = File.join(config['output_dir'], TRACKER_FILENAME)

    return if !File.exist?(tracker_path)

    if force_overwrite
      LogUtilsHelper.double_log("Overwriting existing tracker file at #{tracker_path} (force overwrite enabled).", :info, tag: 'PubMed Ingest')
      return
    end

    LogUtilsHelper.double_log("Tracker file already exists at #{tracker_path}. Use `force_overwrite: true` to overwrite.", :error, tag: 'PubMed Ingest')
    puts "🚫 Tracker file exists: #{tracker_path}"
    puts '   To overwrite it, pass `force_overwrite: true` in the config or args.'
    exit(1)
  end
end
