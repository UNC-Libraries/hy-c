# frozen_string_literal: true
desc 'Ingest new PDFs from the NASA backlog and attach them to the Hyrax works if matched'
task nasa_backlog_ingest: :environment do
  include Tasks::IngestHelperUtils::RakeTaskHelper
  resume = ENV['RESUME'] || 'false'
  output_dir = ENV['OUTPUT_DIR']
  data_dir = ENV['DATA_DIR']
  admin_set_title = ENV['ADMIN_SET_TITLE']
  depositor_onyen = ENV['DEPOSITOR_ONYEN']

  now = Time.now
  resume_bool = ActiveModel::Type::Boolean.new.cast(resume)

  args = {
    resume: resume,
    output_dir: output_dir,
    data_dir: data_dir,
    admin_set_title: admin_set_title,
    depositor_onyen: depositor_onyen
  }

  if resume_bool
    required_keys = %i[resume output_dir]
  else
    required_keys = %i[resume output_dir data_dir admin_set_title depositor_onyen]
  end

  validate_args!(args, required_keys)
  output_directory = resolve_output_directory(args, now, prefix: 'nasa_backlog_ingest')
  tracker = resume_bool ? retrieve_tracker_json(output_directory) : nil
  config = build_nasa_config(args, tracker, output_directory, now)

  write_intro_banner(config: config, ingest_type: 'NASA Backlog')

  coordinator = Tasks::OstiIngest::Backlog::OstiIngestCoordinatorService.new(config)
  coordinator.run
end

def build_nasa_config(args, tracker, output_dir, now)
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
        'data_dir' => normalize_path(args[:data_dir]).to_s
    }
  end
end
