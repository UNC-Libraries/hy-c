# frozen_string_literal: true
class HtmlSanitizationRemediationService
  DISALLOWED_STYLES = ['font-family', 'font-size'].freeze
  PREVIEW_LENGTH = 200
  
  def self.sanitize_existing_records(report_filepath:, dry_run: false)
    works = find_works_with_disallowed_styles
    
    if works.empty?
      LogUtilsHelper.double_log("No works found with disallowed styling", :info, tag: 'sanitize_existing_records')
      return
    end
    
    results = []
    works.each do |doc|
      work_id = doc['id']
      begin
        work = ActiveFedora::Base.find(work_id)
        
        # Capture before/after for report
        result = {
          work_id: work_id,
          abstract: {
            before: truncate_for_preview(work.abstract&.first),
            after: nil
          }
        }
        
        if dry_run
          # Show what would change
          result[:abstract][:after] = truncate_for_preview(sanitize_html_array(work.abstract)&.first)
          LogUtilsHelper.double_log("DRY RUN: Would sanitize #{work_id}", :info, tag: 'sanitize_existing_records')
        else
          sanitize_abstract!(work)
          result[:abstract][:after] = truncate_for_preview(work.abstract&.first)
          work.save!
          work.update_index
        end
        
        results << result
      rescue => e
        LogUtilsHelper.double_log("Error processing work #{work_id}: #{e.message}", :error, tag: 'sanitize_existing_records')
        next
      end
    end
    
    save_report(results, report_filepath, dry_run) if results.any?
    
    action = dry_run ? 'Would sanitize' : 'Sanitized'
    LogUtilsHelper.double_log("#{action} #{results.size} works", :info, tag: 'sanitize_existing_records')
  end
  
  private
  
  def self.find_works_with_disallowed_styles
    query = 'abstract_tesim:("font-family" OR "font-size")'
    LogUtilsHelper.double_log("Running Solr query: #{query}", :info, tag: 'find_works_with_disallowed_styles')
    response = ActiveFedora::SolrService.get(query, rows: 1000)
    docs = response['response']['docs']
    LogUtilsHelper.double_log("Found #{docs.size} works with disallowed styling", :info, tag: 'find_works_with_disallowed_styles')
    docs
  end
  
  def self.sanitize_abstract!(work)
    work.abstract = sanitize_html_array(work.abstract) if work.respond_to?(:abstract)
  end
  
  def self.sanitize_html_array(values)
    Array(values).map { |val| strip_disallowed_styles(val) }
  end
  
  def self.strip_disallowed_styles(html)
    return html if html.blank?
    # Remove style attributes containing font-family or font-size
    html.gsub(/\s*style\s*=\s*["'][^"']*(?:font-family|font-size)[^"']*["']/i, '')
  end
  
  def self.truncate_for_preview(text)
    return nil if text.blank?
    text.length > PREVIEW_LENGTH ? "#{text[0...PREVIEW_LENGTH]}..." : text
  end
  
  def self.save_report(results, filepath, dry_run)
    payload = {
      dry_run: dry_run,
      sanitized_count: results.size,
      results: results
    }
    JsonFileUtilsHelper.write_json(payload, filepath)
    LogUtilsHelper.double_log("Saved report with #{results.size} entries to #{filepath}", :info, tag: 'save_report')
  rescue => e
    LogUtilsHelper.double_log("Failed to write report to #{filepath}: #{e.message}", :error, tag: 'save_report')
  end
end