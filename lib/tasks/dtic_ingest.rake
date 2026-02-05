# frozen_string_literal: true
desc 'Ingest new PDFs from the DTIC backlog and attach them to the Hyrax works if matched'
task dtic_backlog_ingest: :environment do
  include Tasks::IngestHelperUtils::RakeTaskHelper
  resume = ENV['RESUME'] || 'false'
  input_csv_path = ENV['INPUT_CSV_PATH']
  output_dir = ENV['OUTPUT_DIR']
  full_text_dir = ENV['FULL_TEXT_DIR']
  admin_set_title = ENV['ADMIN_SET_TITLE']
  depositor_onyen = ENV['DEPOSITOR_ONYEN']

  now = Time.now
  resume_bool = ActiveModel::Type::Boolean.new.cast(resume)

  args = {
    resume: resume,
    input_csv_path: input_csv_path,
    output_dir: output_dir,
    full_text_dir: full_text_dir,
    admin_set_title: admin_set_title,
    depositor_onyen: depositor_onyen
  }

  if resume_bool
    required_keys = %i[resume output_dir]
  else
    required_keys = %i[resume input_csv_path output_dir full_text_dir admin_set_title depositor_onyen]
  end

  validate_args!(args, required_keys)
  output_directory = resolve_output_directory(args, now, prefix: 'dtic_backlog_ingest')
  tracker = resume_bool ? retrieve_tracker_json(output_directory) : nil
  config = build_dtic_config(args, tracker, output_directory, now)

  write_intro_banner(config: config, ingest_type: 'DTIC Backlog')

  coordinator = Tasks::DTICIngest::Backlog::DTICIngestCoordinatorService.new(config)
  coordinator.run
end

def build_dtic_config(args, tracker, output_dir, now)
  include Tasks::IngestHelperUtils::RakeTaskHelper
  resume = ActiveModel::Type::Boolean.new.cast(args['resume'])

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
        'admin_set_title' => args[:admin_set_title],
        'depositor_onyen' => args[:depositor_onyen],
        'output_dir' => output_dir,
        'input_csv_path' => normalize_path(args[:input_csv_path]).to_s,
        'full_text_dir' => normalize_path(args[:full_text_dir]).to_s
    }
  end
end
