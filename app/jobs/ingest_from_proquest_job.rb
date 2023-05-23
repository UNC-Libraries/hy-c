# frozen_string_literal: true
# Job which performs an ingest from proquest
class IngestFromProquestJob < IngestFromSourceJob
  def ingest_service
    @ingest_service ||= Tasks::ProquestIngestService.new(config, ingest_status_service)
  end

  def config
    {
      'unzip_dir' => ENV['TEMP_STORAGE'],
      'package_dir' => storage_base_path,
      'depositor_onyen' => @user,
      'admin_set' => 'Dissertation',
      'deposit_title' => "ProQuest Deposit #{Time.now.strftime('%Y-%m-%d')}",
      'deposit_subtype' => 'ProQuest'
    }
  end

  def storage_base_path
    @storage_base_path ||= ENV['INGEST_PROQUEST_PATH']
  end

  def source
    'proquest'
  end
end
