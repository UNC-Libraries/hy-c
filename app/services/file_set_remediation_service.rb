# frozen_string_literal: true
# This class is to remediate FileSets where the file was not attached because the anti-virus service
# was either not running or timed out
class FileSetRemediationService
  def create_csv_of_file_sets_without_files
    CSV.open(csv_file_path, 'a+') do |csv|
      csv << ['file_set_id', 'file_set_url', 'parent_id', 'parent_url']
      FileSet.search_in_batches('*:*') do |batch|
        Rails.logger.info("Finding FileSets without files for FileSets with ids: #{batch.map { |solr_doc| solr_doc['id'] }}")
        add_file_sets_to_csv(csv, batch)
      end
    end
  end

  def add_file_sets_to_csv(csv, batch)
    batch.each do |solr_doc|
      file_set = file_set_by_id(solr_doc['id'])
      next if file_set.nil? || has_files?(file_set)

      Rails.logger.info("Adding FileSet with url: #{url_for(file_set)}")
      csv << [file_set.id, url_for(file_set), file_set.parent&.id, url_for(file_set.parent)]
    end
  end

  def url_for(object)
    Rails.application.routes.url_helpers.url_for(object) if object
  end

  def file_set_by_id(id)
    FileSet.find(id)
  rescue ActiveFedora::ObjectNotFoundError
    Rails.logger.warn("FileSet not found. FileSet identifier: #{id}")
    nil
  end

  # rubocop:disable Naming/PredicateName
  def has_files?(file_set)
    !file_set.files.empty?
  end
  # rubocop:enable Naming/PredicateName

  def csv_file_path
    @csv_file_path ||= begin
      csv_directory = Rails.root.join(ENV['DATA_STORAGE'], 'reports')
      FileUtils.mkdir_p(csv_directory)
      Rails.root.join(ENV['DATA_STORAGE'], 'reports', 'file_sets_without_files.csv')
    end
  end
end
