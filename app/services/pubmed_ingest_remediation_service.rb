# frozen_string_literal: true
class PubmedIngestRemediationService
  def self.find_and_resolve_duplicates!(since:, report_filepath:, dry_run: false)
    LogUtilsHelper.double_log("Starting duplicate DOI remediation (since=#{since}, dry_run=#{dry_run}, report=#{report_filepath})", :info, tag: 'find_and_resolve_duplicates')
    duplicates = find_duplicate_dois(since: since, filepath: report_filepath)
    LogUtilsHelper.double_log("Duplicate scan complete — #{duplicates.size} DOI groups found", :info, tag: 'find_and_resolve_duplicates')

    if duplicates.any?
      resolve_duplicates!(filepath: report_filepath, dry_run: dry_run)
    else
      LogUtilsHelper.double_log("No duplicates found since #{since}, skipping resolution step", :info, tag: 'find_and_resolve_duplicates')
    end
  end

  def self.find_and_update_empty_abstracts(since:, report_filepath:, dry_run: false)
    since_str = since.respond_to?(:iso8601) ? since.iso8601 : Date.parse(since.to_s).iso8601
    solr_range = "#{since_str}T00:00:00Z"..'*'
    LogUtilsHelper.double_log("Scanning for empty abstracts (since=#{since_str}, dry_run=#{dry_run})", :info, tag: 'find_and_update_empty_abstracts')

    updated_work_ids = []
    wip_count = 0
    Article.where(deposited_at_dtsi: solr_range, abstract: ['', nil]).find_each.with_index(1) do |work, idx|
      LogUtilsHelper.double_log("Processing Article #{idx}: #{work.id}", :debug, tag: 'find_and_update_empty_abstracts')
      if dry_run
        LogUtilsHelper.double_log("DRY RUN: Would update abstract for #{work.id}", :info, tag: 'find_and_update_empty_abstracts')
      else
        LogUtilsHelper.double_log("Updating abstract for #{work.id} → 'N/A'", :info, tag: 'find_and_update_empty_abstracts')
        work.update!(abstract: ['N/A'])
        LogUtilsHelper.double_log("Reindexing #{work.id}", :debug, tag: 'find_and_update_empty_abstracts')
        work.update_index
      end
      updated_work_ids << work.id
      # WIP Break
      break if wip_count >= 50
      wip_count += 1
    end

    if updated_work_ids.any?
      LogUtilsHelper.double_log("Writing abstract update report with #{updated_work_ids.size} records to #{report_filepath}", :info, tag: 'find_and_update_empty_abstracts')
      JsonFileUtilsHelper.write_json({ updated_count: updated_work_ids.size, work_ids: updated_work_ids }, report_filepath)
    else
      LogUtilsHelper.double_log("No empty abstracts found since #{since_str} — report not written", :info, tag: 'find_and_update_empty_abstracts')
    end

    action = dry_run ? 'Would update' : 'Updated'
    LogUtilsHelper.double_log("#{action} abstracts for #{updated_work_ids.size} Articles ingested since #{since}", :info, tag: 'find_and_update_empty_abstracts')
  end

  private

  def self.find_duplicate_dois(since:, filepath:)
    since_str   = since.respond_to?(:iso8601) ? since.iso8601 : Date.parse(since.to_s).iso8601
    lower_bound = "#{since_str}T00:00:00Z"
    LogUtilsHelper.double_log("Searching for duplicate DOIs with deposited_at_dtsi >= #{lower_bound}", :info, tag: 'find_duplicate_dois')

    duplicates = Hash.new { |h, k| h[k] = [] }
    count = 0

    Article.where(deposited_at_dtsi: lower_bound..'*').find_each do |work|
      count += 1
      LogUtilsHelper.double_log("Inspecting Article #{work.id}", :debug, tag: 'find_duplicate_dois')
      Array(work.identifier).each do |id_val|
        next unless id_val.start_with?('DOI: https://dx.doi.org/')
        doi = id_val.sub('DOI: https://dx.doi.org/', '')
        duplicates[doi] << work
      end
    end

    LogUtilsHelper.double_log("Scanned #{count} Articles, found #{duplicates.keys.size} DOIs (including uniques)", :info, tag: 'find_duplicate_dois')
    refined_duplicates = duplicates.select { |_doi, works| works.size > 1 }
    LogUtilsHelper.double_log("Refined to #{refined_duplicates.keys.size} duplicate DOI groups", :info, tag: 'find_duplicate_dois')
    save_duplicate_report(refined_duplicates, filepath: filepath)
    refined_duplicates
  end

  def self.resolve_duplicates!(filepath:, dry_run: false)
    LogUtilsHelper.double_log("Loading duplicate report from #{filepath}", :info, tag: 'resolve_duplicates')
    pairs = JsonFileUtilsHelper.read_jsonl(filepath, symbolize_names: true)
    LogUtilsHelper.double_log("Read #{pairs.size} DOI groups from report", :info, tag: 'resolve_duplicates')

    removed_count = 0
    wip_count = 0
    pairs.each_with_index do |pair, idx|
      LogUtilsHelper.double_log("Processing duplicate group #{idx + 1}/#{pairs.size} (DOI=#{pair[:doi]})", :debug, tag: 'resolve_duplicates')
      works = pair[:work_ids].filter_map do |id|
        begin
          Article.find(id)
        rescue ActiveFedora::ObjectNotFoundError
          LogUtilsHelper.double_log("Skipping missing Article #{id}", :warn, tag: 'resolve_duplicates')
          nil
        end
      end

      if works.empty?
        LogUtilsHelper.double_log("No surviving works found for DOI=#{pair[:doi]}, skipping", :warn, tag: 'resolve_duplicates')
        next
      end

      work_to_keep    = works.min_by(&:deposited_at)
      works_to_remove = works - [work_to_keep]

      if dry_run
        LogUtilsHelper.double_log("DRY RUN: Would keep #{work_to_keep.id}, delete #{works_to_remove.map(&:id).join(', ')}", :info, tag: 'resolve_duplicates')
      else
        works_to_remove.each do |work|
          LogUtilsHelper.double_log("Destroying duplicate work #{work.id}", :info, tag: 'resolve_duplicates')
          work.destroy
          removed_count += 1
        end
      end
      # WIP Break 
      break if wip_count >= 50
      wip_count += 1
    end

    LogUtilsHelper.double_log(
      dry_run ? "DRY RUN complete — #{pairs.size} groups processed" : "Resolved duplicates, removed #{removed_count} works",
      :info,
      tag: 'resolve_duplicates'
    )
  end

  def self.save_duplicate_report(duplicates, filepath:)
    LogUtilsHelper.double_log("Preparing to write duplicate report to #{filepath}", :info, tag: 'save_duplicate_report')
    payload = duplicates.map { |doi, works| { doi: doi, work_ids: works.map(&:id) } }
    JsonFileUtilsHelper.write_jsonl(payload, filepath, mode: 'w')
    LogUtilsHelper.double_log("Saved duplicate report with #{payload.size} entries to #{filepath}", :info, tag: 'save_duplicate_report')
  rescue => e
    LogUtilsHelper.double_log("Failed to write duplicate report to #{filepath}: #{e.class} - #{e.message}", :error, tag: 'save_duplicate_report')
  end
end