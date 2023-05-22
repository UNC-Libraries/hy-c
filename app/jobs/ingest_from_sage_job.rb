# frozen_string_literal: true
# Job which performs ingest of sage packages
class IngestFromSageJob < IngestFromProviderJob
  def ingest_service
    @ingest_service ||= Tasks::SageIngestService.new(config, ingest_status_service)
  end

  def config
    {
      'unzip_dir' => ENV['TEMP_STORAGE'],
      'package_dir' => storage_base_path,
      'depositor_onyen' => 'admin',
      'admin_set' => 'Open_Access_Articles_and_Book_Chapters'
    }
  end

  def storage_base_path
    @storage_base_path ||= ENV['INGEST_SAGE_PATH']
  end

  def provider
    'sage'
  end
end
