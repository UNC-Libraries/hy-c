# frozen_string_literal: true
desc 'Ingest new PDFs from the NSF backlog and attach them to Hyrax works if matched'
task :nsf_backlog_ingest, [:file_info_csv, :file_retrieval_directory, :output_dir, :admin_set_title, :depositor_onyen] => :environment do |task, args|
  return unless valid_args('nsf_ingest', args[:file_retrieval_directory], args[:output_dir], args[:admin_set_title], args[:depositor_onyen], args[:file_info_csv])
  file_retrieval_directory = Pathname.new(args[:file_retrieval_directory]).absolute? ?
                               args[:file_retrieval_directory] :
                               Rails.root.join(args[:file_retrieval_directory])
  coordinator = Tasks::NsfIngest::Backlog::NsfIngestCoordinatorService.new({
      'admin_set_title' => args[:admin_set_title],
      'depositor_onyen' => args[:depositor_onyen],
      'file_retrieval_directory' => file_retrieval_directory,
      'output_dir' => args[:output_dir],
      'file_info_csv' => args[:file_info_csv]
  })
  res = coordinator.run
end
