# frozen_string_literal: true
class ListFileSetsWithoutFilesJob < Hyrax::ApplicationJob
  queue_as :long_running_jobs

  def perform
    service = FileSetRemediationService.new
    service.create_csv_of_file_sets_without_files
  end
end
