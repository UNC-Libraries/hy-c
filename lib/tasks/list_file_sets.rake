# frozen_string_literal: true
desc 'Create a csv of file_sets that do not have files associated with them'
task list_file_sets: :environment do
  ListFileSetsWithoutFilesJob.perform_later
end
