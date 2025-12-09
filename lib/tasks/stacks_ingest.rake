# frozen_string_literal: true
desc 'Ingest new PDFs from the Stacks CDC backlog and attach them to Hyrax works if matched'
task :stacks_backlog_ingest, [:resume, :input_csv_path, :output_dir, :full_text_dir, :admin_set_title, :depositor_onyen] => :environment do |_task, args|
  include Tasks::IngestHelperUtils::RakeTaskHelper

  now = Time.now
  resume = ActiveModel::Type::Boolean.new.cast(args[:resume])

  required_keys = %i[resume, full_text_dir output_dir admin_set_title depositor_onyen, input_csv_path]
  validate_args!(args, required_keys) unless resume

  output_directory = resolve_output_directory(args, now, prefix: 'stacks_backlog_ingest')
  tracker = resume ? retrieve_tracker_json(output_directory) : nil
  config = build_stacks_config(args, tracker, output_directory, now)

  write_intro_banner(config: config, ingest_type: 'Stacks CDC')

  coordinator = Tasks::StacksIngest::Backlog::StacksIngestCoordinatorService.new(config)
  coordinator.run
end

def build_stacks_config(args, tracker, output_dir, now)
  include Tasks::IngestHelperUtils::RakeTaskHelper
  resume = ActiveModel::Type::Boolean.new.cast(args[:resume])

  if resume
    tracker.merge('restart_time' => now, 'resume' => true)
  else
    {
      'start_time' => now,
      'restart_time' => nil,
      'resume' => false,
      'admin_set_title' => args[:admin_set_title],
      'depositor_onyen' => args[:depositor_onyen],
      'output_dir' => output_dir,
      'input_csv_path' => normalize_path(args[:input_csv]),
      'full_text_dir' => normalize_path(args[:full_text_dir])
    }
  end
end
