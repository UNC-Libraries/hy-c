# frozen_string_literal: true
# app/services/doi_tesim_remediation_service.rb
class DoiTesimRemediationService
  attr_reader :updated_count, :error_count, :skipped_count

  def initialize
    @updated_count = 0
    @error_count = 0
    @skipped_count = 0
  end

  def normalize_all_dois
    docs = find_works_with_bare_dois

    Rails.logger.info("[DoiRemediation] Found #{docs.size} works with non-canonical DOI format")
    return if docs.empty?

    docs.each do |doc|
      normalize_work_doi(doc)
    end

    log_summary
  end

  def normalize_work_doi(doc)
    work_id = doc['id']
    current_doi = doc['doi_tesim']&.first

    return increment_skip unless current_doi.present?

    normalized_doi = WorkUtilsHelper.normalize_doi_to_canonical(current_doi)

    if normalized_doi == current_doi
      increment_skip
      return
    end

    update_work_doi(work_id, normalized_doi)
  rescue => e
    Rails.logger.error("[DoiRemediation] Error processing #{work_id}: #{e.message}")
    @error_count += 1
  end

  private

  def find_works_with_bare_dois
    # Find all works with DOIs that don't start with https://
    query = 'doi_tesim:[* TO *] AND -doi_tesim:"https://*"'
    response = ActiveFedora::SolrService.get(query, rows: 10000, fl: 'id,doi_tesim')
    response['response']['docs']
  end

  def update_work_doi(work_id, normalized_doi)
    work = ActiveFedora::Base.find(work_id)
    work.doi = normalized_doi
    work.save!
    @updated_count += 1
    Rails.logger.info("[DoiRemediation] Updated #{work_id}")
  end

  def increment_skip
    @skipped_count += 1
  end

  def log_summary
    Rails.logger.info("[DoiRemediation] Summary - Updated: #{@updated_count}, Errors: #{@error_count}, Skipped: #{@skipped_count}")
  end
end
