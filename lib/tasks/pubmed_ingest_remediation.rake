# /lib/tasks/remediate_pubmed_ingest.rake
# frozen_string_literal: true
namespace :pubmed do
  desc 'Remediate duplicate DOIs and/or empty abstracts from a recent ingest run'
  task :remediate, [:start_date, :end_date, :dry_run, :output_dir] => :environment do |_t, args|
    start_date = args[:start_date]
    end_date   = args[:end_date]
    dry_run   = args[:dry_run].to_s.downcase == 'true'
    timestamp = Time.now.strftime('%Y-%m-%d_%H-%M-%S')

    unless args[:output_dir]
      puts '❌ You must specify an OUTPUT_DIR (e.g., OUTPUT_DIR=tmp/pubmed_remediation)'
      exit 1
    end

    output_dir = Pathname.new(args[:output_dir]).join("pubmed_remediation_#{timestamp}")
    FileUtils.mkdir_p(output_dir)

    unless start_date && end_date
      puts '❌ You must specify both START_DATE and END_DATE (e.g., START_DATE=2023-01-01 END_DATE=2023-01-31)'
      exit 1
    end


    begin
      start_date_obj = Date.parse(start_date)
      end_date_obj = Date.parse(end_date)
    rescue ArgumentError
      puts '❌ Invalid date format for START_DATE or END_DATE'
      exit 1
    end

    puts "🔍 Running PubMed remediation from #{start_date}#{end_date ? " to #{end_date}" : ''} (dry_run=#{dry_run})"
    puts "📂 Reports will be saved under: #{output_dir}"

    # 1️⃣ Find and resolve duplicates
    duplicate_report = output_dir.join('duplicate_dois.jsonl')
    PubmedIngestRemediationService.find_and_resolve_duplicates!(
      start_date: start_date_obj,
      end_date: end_date_obj,
      report_filepath: duplicate_report,
      dry_run: dry_run
    )

    # 2️⃣ Find and update empty abstracts
    abstract_report = output_dir.join('empty_abstracts.json')
    PubmedIngestRemediationService.find_and_update_empty_abstracts(
      start_date: start_date_obj,
      end_date: end_date_obj,
      report_filepath: abstract_report,
      dry_run: dry_run
    )

    puts dry_run ? "✅ Dry run completed — check reports under #{output_dir}" :
                   '✅ Remediation completed — changes applied.'
  end
end
