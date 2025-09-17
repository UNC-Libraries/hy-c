# frozen_string_literal: true
class PubmedIngestRemediationService
  def self.find_and_resolve_duplicates!(start_date:, end_date:, report_filepath:, dry_run: false)
    duplicates = find_duplicate_dois(start_date: start_date, end_date: end_date, filepath: report_filepath)
    if duplicates.any?
      resolve_duplicates!(filepath: report_filepath, dry_run: dry_run)
    else
      LogUtilsHelper.double_log("No duplicates found in range #{start_date} to #{end_date}", :info, tag: 'find_and_resolve_duplicates')
    end
  end

  def self.find_and_update_empty_abstracts(start_date:, end_date:, report_filepath:, dry_run: false)
    start_str = start_date.strftime('%Y-%m-%dT00:00:00Z')
    end_str   = end_date.strftime('%Y-%m-%dT23:59:59Z')
    query     = [
      'has_model_ssim:"Article"',
      "system_create_dtsi:[#{start_str} TO #{end_str}]",
      # Find works with missing abstract
      '-abstract_tesim:["" TO *]'
    ].join(' AND ')

    LogUtilsHelper.double_log("Running Solr query for empty abstracts: #{query}", :info, tag: 'find_and_update_empty_abstracts')

    response = ActiveFedora::SolrService.get(query, rows: 10_000)
    docs = response['response']['docs']
    LogUtilsHelper.double_log("Found #{docs.size} works with empty abstract", :info, tag: 'find_and_update_empty_abstracts')


    updated_ids = []
    docs.each do |doc|
      work_id = doc['id']
      if dry_run
        LogUtilsHelper.double_log("DRY RUN: Would update abstract for #{work_id}", :info, tag: 'find_and_update_empty_abstracts')
      else
        work = Article.find(work_id)
        work.update!(abstract: ['N/A'])
        work.update_index
      end
      updated_ids << work_id
    end

    JsonFileUtilsHelper.write_json({ updated_count: updated_ids.size, work_ids: updated_ids }, report_filepath) if updated_ids.any?

    action = dry_run ? 'Would update' : 'Updated'
    LogUtilsHelper.double_log("#{action} abstracts for #{updated_ids.size} Articles", :info, tag: 'find_and_update_empty_abstracts')
  end

  private

  def self.find_duplicate_dois(start_date:, end_date:, filepath:)
    start_str = start_date.strftime('%Y-%m-%dT00:00:00Z')
    end_str   = end_date.strftime('%Y-%m-%dT23:59:59Z')
    query     = [
      'has_model_ssim:"Article"',
      "system_create_dtsi:[#{start_str} TO #{end_str}]"
    ].join(' AND ')

    LogUtilsHelper.double_log("Running Solr query for duplicate DOIs: #{query}", :info, tag: 'find_duplicate_dois')

    response = ActiveFedora::SolrService.get(query, rows: 10_000)
    docs = response['response']['docs']
    LogUtilsHelper.double_log("Found #{docs.size} Article records in date range", :info, tag: 'find_duplicate_dois')
    duplicates = Hash.new { |h, k| h[k] = [] }

    docs.each do |doc|
      work_id = doc['id']
      Array(doc['identifier_tesim']).each do |id_val|
        LogUtilsHelper.double_log("Checking identifier #{id_val} for work #{work_id}", :debug, tag: 'find_duplicate_dois')
        if id_val.start_with?('DOI: https://')
          normalized = id_val.sub(/^DOI:\s*https?:\/\/(dx\.)?doi\.org\//i, '')
          duplicates[normalized] << { id: work_id, created_at: doc['system_create_dtsi'] }
        end
      end
    end

    refined_duplicates = duplicates.select { |_doi, works| works.size > 1 }
    save_duplicate_report(refined_duplicates, filepath: filepath)
    refined_duplicates
  end

  def self.resolve_duplicates!(filepath:, dry_run: false)
    pairs = JsonFileUtilsHelper.read_jsonl(filepath, symbolize_names: true)
    removed_count = 0
    LogUtilsHelper.double_log("Resolving #{pairs.size} duplicate DOI groups from #{filepath}", :info, tag: 'resolve_duplicates')

    pairs.each do |pair|
      works = pair[:work_ids].zip(pair[:timestamps]).filter_map do |id, timestamp|
        begin
          obj = Article.find(id)
          { id: id, obj: obj, created_at: timestamp }
        rescue ActiveFedora::ObjectNotFoundError
          LogUtilsHelper.double_log("Skipping missing Article #{id}", :warn, tag: 'resolve_duplicates')
          nil
        end
      end

      next if works.empty?

      work_to_keep = works.min_by { |w| w[:created_at] }
      works_to_remove = works.reject { |w| w[:id] == work_to_keep[:id] }

      if dry_run
        LogUtilsHelper.double_log(
          "DRY RUN: Would keep #{work_to_keep[:id]}, would delete #{works_to_remove.map { |w| w[:id] }.join(', ')}",
          :info,
          tag: 'resolve_duplicates'
        )
      else
        works_to_remove.each { |w| w[:obj].destroy }
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
    payload = duplicates.map do |doi, works|
      { doi: doi, work_ids: works.map { |w| w[:id] }, timestamps: works.map { |w| w[:created_at] } }
    end
    LogUtilsHelper.double_log("Writing duplicate report with #{payload.size} entries to #{filepath}", :info, tag: 'save_duplicate_report')
    JsonFileUtilsHelper.write_jsonl(payload, filepath, mode: 'w')
    LogUtilsHelper.double_log("Saved duplicate report with #{payload.size} entries to #{filepath}", :info, tag: 'save_duplicate_report')
  rescue => e
    LogUtilsHelper.double_log("Failed to write duplicate report to #{filepath}: #{e.message}", :error, tag: 'save_duplicate_report')
  end
end
