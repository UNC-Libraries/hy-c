# lib/tasks/helpers/task_helper.rb
module DimensionsIngestHelper
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
