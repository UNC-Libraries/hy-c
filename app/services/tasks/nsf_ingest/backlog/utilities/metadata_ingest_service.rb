# frozen_string_literal: true
class Tasks::NsfIngest::Backlog::Utilities::MetadataIngestService
  include Tasks::IngestHelperUtils::IngestHelper
  include Tasks::IngestHelperUtils::MetadataIngestHelper
  include Tasks::NsfIngest::Backlog::Utilities::MetadataRetrievalHelper

  def initialize(config:, tracker:, md_ingest_results_path:)
    @config = config
    @file_info_csv_path = config['file_info_csv_path']
    @output_dir = config['output_dir']
    @md_ingest_results_path = md_ingest_results_path
    @admin_set = AdminSet.where(title: config['admin_set_title']).first
    @tracker = tracker
    @write_buffer = []
    @flush_threshold = 100
    @seen_identifier_list = load_last_results('doi')
  end

  def identifier_key_name
    'doi'
  end

  def process_backlog
    records_from_csv = remaining_records_from_csv(@seen_identifier_list)

    records_from_csv.each do |record|
      doi = record['doi']
      next if @seen_identifier_list.include?(doi) && doi.present?
      match = WorkUtilsHelper.fetch_work_data_by_doi(doi, admin_set_title: @config['admin_set_title'])
      if match.present? && match[:work_id].present?
        skip_existing_work(doi, match, filename: record['filename'])
        next
      end

      crossref_md = fetch_metadata_for_doi(source: 'crossref', doi: doi)
      openalex_md = fetch_metadata_for_doi(source: 'openalex', doi: doi)
      datacite_md = fetch_metadata_for_doi(source: 'datacite', doi: doi)

      source = verify_source_md_available(crossref_md, openalex_md, doi)
      resolved_md = merge_metadata_sources(crossref_md, openalex_md, datacite_md)
      attr_builder = construct_attribute_builder(resolved_md)

      article = new_article(metadata: resolved_md, attr_builder: attr_builder, config: @config)
      record_result(category: :successfully_ingested_metadata_only, identifier: doi, article: article, filename: record['filename'])

      Rails.logger.info("[MetadataIngestService] Created new Article #{article.id} for record #{record.inspect}")
    rescue => e
      handle_record_error(doi, e, filename: record['filename'])
    ensure
      flush_buffer_if_needed
    end

    flush_buffer_to_file unless @write_buffer.empty?
    LogUtilsHelper.double_log("[MetadataIngestService] Ingest complete. Processed #{records_from_csv.size} records.", :info, tag: 'MetadataIngestService')
  end

  private

  def remaining_records_from_csv(seen_list)
    records = CSV.read(@file_info_csv_path, headers: true).map(&:to_h)
    records.reject do |record|
      doi = record['doi']
      doi.present? && seen_list.include?(doi)
    end
  end

  def verify_source_md_available(crossref_md, openalex_md, doi)
    return if crossref_md && openalex_md

    if crossref_md.nil? && openalex_md.nil?
      raise "No metadata found from Crossref or OpenAlex for DOI #{doi}."
    end

    missing_source = crossref_md.nil? ? 'Crossref' : 'OpenAlex'
    chosen_source  = crossref_md.nil? ? 'OpenAlex' : 'Crossref'
    LogUtilsHelper.double_log(
      "No metadata found from #{missing_source} for DOI #{doi}. Using #{chosen_source} metadata.",
      :warn,
      tag: 'MetadataIngestService'
    )
  end


  def merge_metadata_sources(crossref_md, openalex_md, datacite_md)
    # Default to OpenAlex metadata if available else Crossref
    resolved_md = openalex_md || crossref_md
    resolved_md['source'] = openalex_md.present? ? 'openalex' : 'crossref'
    resolved_md['openalex_abstract'] = generate_openalex_abstract(openalex_md)
    resolved_md['datacite_abstract'] = datacite_md.dig('attributes', 'description') if datacite_md&.dig('attributes', 'description').present?
    resolved_md['openalex_keywords'] = extract_keywords_from_openalex(openalex_md)
    resolved_md
  end

  def construct_attribute_builder(resolved_md)
    case resolved_md['source']
    when 'openalex'
      Tasks::NsfIngest::Backlog::Utilities::AttributeBuilders::OpenalexAttributeBuilder.new(resolved_md, @admin_set, @config['depositor_onyen'])
    when 'crossref'
      Tasks::NsfIngest::Backlog::Utilities::AttributeBuilders::CrossrefAttributeBuilder.new(resolved_md, @admin_set, @config['depositor_onyen'])
    end
  end
end
