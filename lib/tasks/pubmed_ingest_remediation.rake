# /lib/tasks/remediate_pubmed_ingest.rake
# frozen_string_literal: true
namespace :pubmed do
  desc 'Remediate duplicate DOIs and/or empty abstracts from a recent ingest run'
  task :remediate, [:since, :dry_run] => :environment do |_t, args|
    since     = args[:since]
    dry_run   = args[:dry_run].to_s.downcase == 'true'
    timestamp = Time.now.strftime('%Y-%m-%d_%H-%M-%S')
    output_dir = Rails.root.join('tmp', 'pubmed_remediation', timestamp)
    FileUtils.mkdir_p(output_dir)

    unless since
      puts '❌ You must specify a SINCE date (e.g., SINCE=2025-09-01)'
      exit 1
    end


    begin
      since_date = Date.parse(since)
    rescue ArgumentError
      puts "❌ Invalid date format for SINCE: #{since}"
      exit 1
    end

    puts "🔍 Running PubMed remediation since #{since} (dry_run=#{dry_run})"
    puts "📂 Reports will be saved under: #{output_dir}"

    # 1️⃣ Find and resolve duplicates
    duplicate_report = output_dir.join('duplicate_dois.jsonl')
    PubmedIngestRemediationService.find_and_resolve_duplicates!(
      since: since_date,
      report_filepath: duplicate_report,
      dry_run: dry_run
    )

    # 2️⃣ Find and update empty abstracts
    abstract_report = output_dir.join('empty_abstracts.json')
    PubmedIngestRemediationService.find_and_update_empty_abstracts(
      since: since_date,
      report_filepath: abstract_report,
      dry_run: dry_run
    )

    puts dry_run ? "✅ Dry run completed — check reports under #{output_dir}" :
                   '✅ Remediation completed — changes applied.'
  end
end
