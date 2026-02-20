# frozen_string_literal: true
# lib/tasks/doi_normalization.rake
namespace :doi do
  desc 'Normalize DOI values in doi_tesim to canonical https://doi.org/ format'
  task normalize_doi_tesim: :environment do
    require 'progressbar'

    service = DoiTesimRemediationService.new

    # Get count first for progress bar
    query = 'doi_tesim:[* TO *] AND -doi_tesim:"https://*"'
    response = ActiveFedora::SolrService.get(query, rows: 0)
    total = response['response']['numFound']

    puts "Found #{total} works with non-canonical DOI format"
    return if total.zero?

    progress = ProgressBar.create(
      title: 'Normalizing DOIs',
      total: total,
      format: '%a %e %P% Processed: %c from %C'
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
