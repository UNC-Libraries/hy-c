# This class is to remediate FileSets where the file was not attached because the anti-virus service
# was either not running or timed out
class FileSetRemediationService
  def create_csv_of_file_sets_without_files
    CSV.open(csv_file_path, 'a+') do |csv|
      csv << ['file_set_id', 'url']
      FileSet.search_in_batches('*:*') do |group|
        group.each do |solr_doc|
          file_set = FileSet.find(solr_doc['id'])
          next unless file_set

          next if has_files?(file_set)

          csv << [file_set.id, Rails.application.routes.url_helpers.url_for(file_set)]
        rescue ActiveFedora::ObjectNotFoundError
          Rails.logger.warn("FileSet not found. FileSet identifier: #{identifier}")
          nil
        end
      end
    end
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
