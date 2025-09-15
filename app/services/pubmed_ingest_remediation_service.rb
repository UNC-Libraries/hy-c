# frozen_string_literal: true
class PubmedIngestRemediationService
  def self.find_and_resolve_duplicates!(since:, report_filepath:, dry_run: false)
    duplicates = find_duplicate_dois(since: since, filepath: report_filepath)
    if duplicates.any?
      resolve_duplicates!(filepath: report_filepath, dry_run: dry_run)
    else
      LogUtilsHelper.double_log("No duplicates found since #{since}", :info, tag: 'find_and_resolve_duplicates')
    end
  end

  def self.find_and_update_empty_abstracts(since:, report_filepath:, dry_run: false)
    since_str = since.respond_to?(:iso8601) ? since.iso8601 : Date.parse(since.to_s).iso8601
    solr_range = "#{since_str}T00:00:00Z"..'*'

    updated_work_ids = []
    Article.where(deposited_at_dtsi: solr_range, abstract: ['', nil]).find_each do |work|
      if dry_run
        LogUtilsHelper.double_log("DRY RUN: Would update abstract for #{work.id}", :info, tag: 'find_and_update_empty_abstracts')
      else
        work.update!(abstract: ['N/A'])
        work.update_index
      end
      updated_work_ids << work.id
    end

    if updated_work_ids.any?
      JsonFileUtilsHelper.write_json({ updated_count: updated_work_ids.size, work_ids: updated_work_ids }, report_filepath)
    end

    action = dry_run ? 'Would update' : 'Updated'
    LogUtilsHelper.double_log("#{action} abstracts for #{updated_work_ids.size} Articles ingested since #{since}", :info, tag: 'find_and_update_empty_abstracts')
  end

  private

  def self.find_duplicate_dois(since:, filepath:)
    since_str = since.respond_to?(:iso8601) ? since.iso8601 : Date.parse(since.to_s).iso8601
    lower_bound = "#{since_str}T00:00:00Z"

    duplicates = Hash.new { |h, k| h[k] = [] }

    # Fix: Use a range instead of array, or use proper Solr query syntax
    # Option 1: Use range syntax (preferred)
    Article.where(deposited_at_dtsi: lower_bound..'*').find_each do |work|
      Array(work.identifier).each do |id_val|
        next unless id_val.start_with?('DOI: https://dx.doi.org/')
        doi = id_val.sub('DOI: https://dx.doi.org/', '')
        duplicates[doi] << work
      end
    end

    refined_duplicates = duplicates.select { |_doi, works| works.size > 1 }
    save_duplicate_report(refined_duplicates, filepath: filepath)
    refined_duplicates
  end

  def self.resolve_duplicates!(filepath:, dry_run: false)
    pairs = JsonFileUtilsHelper.read_jsonl(filepath, symbolize_names: true)
    removed_count = 0

    pairs.each do |pair|
      works = pair[:work_ids].filter_map do |id|
        begin
          Article.find(id)
        rescue ActiveFedora::ObjectNotFoundError
          LogUtilsHelper.double_log("Skipping missing Article #{id}", :warn, tag: 'resolve_duplicates')
          nil
        end
      end

      next if works.empty?

      work_to_keep = works.min_by(&:deposited_at)
      works_to_remove = works - [work_to_keep]

      if dry_run
        LogUtilsHelper.double_log("DRY RUN: Would keep #{work_to_keep.id}, would delete #{works_to_remove.map(&:id).join(', ')}", :info, tag: 'resolve_duplicates')
      else
        works_to_remove.each(&:destroy)
        removed_count += works_to_remove.size
      end
    end

    LogUtilsHelper.double_log(
      dry_run ? "DRY RUN: #{pairs.size} duplicate DOI groups found." : "Resolved duplicates, removed #{removed_count} works",
      :info,
      tag: 'resolve_duplicates'
    )
  end

  def self.save_duplicate_report(duplicates, filepath:)
    payload = duplicates.map { |doi, works| { doi: doi, work_ids: works.map(&:id) } }
    JsonFileUtilsHelper.write_jsonl(payload, filepath, mode: 'w')
    LogUtilsHelper.double_log("Saved duplicate report with #{payload.size} entries to #{filepath}", :info, tag: 'save_duplicate_report')
  rescue => e
    LogUtilsHelper.double_log("Failed to write duplicate report to #{filepath}: #{e.message}", :error, tag: 'save_duplicate_report')
  end
end
