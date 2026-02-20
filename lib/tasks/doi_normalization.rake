# frozen_string_literal: true
# lib/tasks/doi_normalization.rake
namespace :doi do
  desc 'Normalize DOI values in doi_tesim to canonical https://doi.org/ format'
  task normalize_doi_tesim: :environment do
    require 'ruby-progressbar'

    service = DoiTesimRemediationService.new

    # Get count first for progress bar
    response = service.find_works_with_bare_dois_response
    total = response['response']['numFound']

    puts "Found #{total} works with non-canonical DOI format"
    return if total.zero?

    progress = ProgressBar.create(
      title: 'Normalizing DOIs',
      total: total,
      format: '%a %e %P% Processed: %c from %C',
      starting_at: 0
    )

    # Monkey-patch the service to update progress bar
    service.define_singleton_method(:normalize_work_doi) do |doc|
      super(doc)
    ensure
      progress.increment
    end

    service.normalize_all_dois

    puts "\n\nSummary:"
    puts "  Updated: #{service.updated_count}"
    puts "  Errors: #{service.error_count}"
    puts "  Skipped: #{service.skipped_count}"
  end
end
