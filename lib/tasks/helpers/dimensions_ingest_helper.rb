# lib/tasks/helpers/task_helper.rb
module DimensionsIngestHelper
  def ping_dimensions_api(dimensions_url)
    uri = URI(dimensions_url)
    response = Net::HTTP.get_response(uri)

    if response.is_a?(Net::HTTPSuccess)
      puts "Dimensions API is up! Status: #{response.code}"
      true
    else
      puts "Dimensions API is down or there was an error. Status: #{response.code}"
      false
    end
  rescue StandardError => e
    puts "An error occurred: #{e.message}"
    false
  end

  def save_last_run_time(task_name)
    File.open(Rails.root.join('log', "last_#{task_name}_run.txt"), 'w') do |f|
      f.puts Time.current
    end
  end

  def read_last_run_time(task_name)
    file_path = Rails.root.join('log', "last_#{task_name}_run.txt")
    if File.exist?(file_path)
      File.read(file_path).strip
    else
      nil
    end
  end
  end
