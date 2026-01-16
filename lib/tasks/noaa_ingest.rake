# frozen_string_literal: true
desc 'Ingest new PDFs from the NOAA backlog and attach them to the Hyrax works if matched'
task noaa_backlog_ingest: :environment do
  include Tasks::IngestHelperUtils::RakeTaskHelper
  resume = ENV['RESUME'] || 'false'
  input_csv_path = ENV['INPUT_CSV_PATH']
  output_dir = ENV['OUTPUT_DIR']
  full_text_dir = ENV['FULL_TEXT_DIR']
  admin_set_title = ENV['ADMIN_SET_TITLE']
  depositor_onyen = ENV['DEPOSITOR_ONYEN']

  now = Time.now
  resume_bool = ActiveModel::Type::Boolean.new.cast(resume)

  if resume_bool
    required_keys = %i[resume output_dir]
  else
    required_keys = %i[resume input_csv_path output_dir full_text_dir admin_set_title depositor_onyen]
  end

  validate_args!(ENV, required_keys)
  output_directory = resolve_output_directory(ENV, now, prefix: 'noaa_backlog_ingest')
  tracker = resume_bool ? retrieve_tracker_json(output_directory) : nil
  config = build_noaa_config(ENV, tracker, output_directory, now)

  write_intro_banner(config: config, ingest_type: 'NOAA Backlog')

  coordinator = Tasks::NoaaIngest::Backlog::NoaaIngestCoordinatorService.new(config)
  coordinator.run
end

def build_noaa_config(env, tracker, output_dir, now)
  include Tasks::IngestHelperUtils::RakeTaskHelper
  resume = ActiveModel::Type::Boolean.new.cast(env['RESUME'])

  if resume
    tracker.merge(
        'restart_time' => now,
        'resume' => true
    )
  else
    {
        'start_time' => now,
        'restart_time' => nil,
        'resume' => false,
        'admin_set_title' => env['ADMIN_SET_TITLE'],
        'depositor_onyen' => env['DEPOSITOR_ONYEN'],
        'output_dir' => output_dir,
        'input_csv_path' => normalize_path(env['INPUT_CSV_PATH']).to_s,
        'full_text_dir' => normalize_path(env['FULL_TEXT_DIR']).to_s
    }
  end
end
