# frozen_string_literal: true
# lib/tasks/html_sanitization.rake
namespace :remediation do
  desc 'Sanitize HTML in existing records with disallowed styling'
  task sanitize_html: :environment do
    report_path = ENV['REPORT_PATH']
    # Default to true
    dry_run = ENV['DRY_RUN'] != 'false'

    puts 'Starting HTML sanitization remediation...'
    puts "Dry run: #{dry_run}"
    puts "Report will be saved to: #{report_path}"

    HtmlSanitizationRemediationService.sanitize_existing_records(
      report_filepath: report_path,
      dry_run: dry_run
    )

    puts "Done! Check report at #{report_path}"
  end
end
