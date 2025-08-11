# frozen_string_literal: true
# Notes:
# 1. Script uses PMC-OAI API to retrieve metadata and make comparisons of alternate IDs. (PMCID, PMID)
# 2. PMC requests scripts making >100 requests be ran outside of peak hours. (5 AM - 9 PM)
DEPOSITOR = ENV['PUBMED_INGEST_DIMENSIONS_INGEST_DEPOSITOR_ONYEN']
SUBDIRS = %w[01_build_id_lists 02_load_and_ingest_metadata 03_attach_files_to_works]
REQUIRED_ARGS = %w[start_date end_date admin_set_title]

desc 'Ingest works from the PubMed API'
# Required args for a new ingest:
#   - start_date: The start date for the ingest (format: YYYY-MM-DD)
#   - end_date: The end date for the ingest (format: YYYY-MM-DD)
#   - admin_set_title: The title of the AdminSet to use for the works
# Recommended args:
#   - depositor_onyen: The onyen of the depositor (default: PUBMED_INGEST_DIMENSIONS_INGEST_DEPOSITOR_ONYEN env var)
#   - full_text_dir: The directory to store full-text PDFs (default: a subdirectory of the output directory. hyrax may encounter issues with the default tmp directory on remote)
#   - output_dir: The directory to store output files (default: a subdirectory of the tmp directory. similar issues with permissions as above)

# Required args for a resume:
#   - output_dir: The directory where the previous ingest's output files are stored (must contain an ingest_tracker.json file)
#   - resume: A flag to indicate that this is a resume operation (default: false)
#  - All other args on resume will be ignored, and the ingest will resume from the last saved state.

# Example usage:
#   bundle exec rake "pubmed_ingest[true,tmp/pubmed_ingest_2025-08-07_20-22-03,,,,]"
#   bundle exec rake "pubmed_ingest[false,/path/to/output/dir,/path/to/full_text_dir,2024-01-01,2024-01-31,default,admin]"
#   bundle exec rake "pubmed_ingest[false,,,2024-01-01,2024-01-31,default,admin]"

desc 'Ingest works from the PubMed API'
task :pubmed_ingest, [:resume, :output_dir, :full_text_dir, :start_date, :end_date, :admin_set_title, :depositor_onyen] => :environment do |t, args|
  options = {}
  options[:resume] = ActiveModel::Type::Boolean.new.cast(args[:resume])
  options[:start_date] = args[:start_date]
  options[:end_date] = args[:end_date]
  options[:admin_set_title] = args[:admin_set_title]
  options[:output_dir] = args[:output_dir]
  options[:full_text_dir] = args[:full_text_dir]
  options[:depositor_onyen] = args[:depositor_onyen] || DEPOSITOR


  puts "Starting PubMed ingest with options: #{options.inspect}"

  config, tracker = Tasks::PubmedIngest::Recurring::PubmedIngestCoordinatorService.build_pubmed_ingest_config_and_tracker(args: options)

  coordinator = Tasks::PubmedIngest::Recurring::PubmedIngestCoordinatorService.new(config, tracker)
  coordinator.run
end

desc 'Ingest new PubMed PDFs from the backlog and attach them to Hyrax works if matched'
task :pubmed_backlog_ingest, [:file_retrieval_directory, :output_dir, :admin_set_title] => :environment do |task, args|
  return unless valid_args('pubmed_ingest', args[:file_retrieval_directory], args[:output_dir], args[:admin_set_title])
  file_retrieval_directory = Pathname.new(args[:file_retrieval_directory]).absolute? ?
                             args[:file_retrieval_directory] :
                             Rails.root.join(args[:file_retrieval_directory])
  coordinator = Tasks::PubmedIngest::Backlog::PubmedIngestCoordinatorService.new({
    'admin_set_title' => args[:admin_set_title],
    'depositor_onyen' => args[:depositor_onyen],
    'file_retrieval_directory' => file_retrieval_directory,
    'output_dir' => args[:output_dir]
  })
  res = coordinator.run
end
