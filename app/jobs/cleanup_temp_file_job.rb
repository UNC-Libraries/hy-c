# app/jobs/cleanup_temp_file_job.rb
class CleanupTempFileJob < ApplicationJob
  queue_as :default

  def perform(file_path)
    if File.exist?(file_path)
      File.delete(file_path)
      Rails.logger.info "Cleaned up temp file: #{file_path}"
    else
      Rails.logger.info "Temp file already cleaned up: #{file_path}"
    end
  rescue => e
    Rails.logger.error "Failed to clean up temp file #{file_path}: #{e.message}"
  end
end