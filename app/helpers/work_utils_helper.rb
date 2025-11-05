# frozen_string_literal: true
# NOTE: Leverage the admin_set_title parameter when building ingest tools. Incomplete indexes can lead to incorrect or missing results.
module WorkUtilsHelper
  def self.fetch_work_data_by_alternate_identifier(identifier, admin_set_title: nil)
    query = "identifier_tesim:\"#{identifier}\" NOT has_model_ssim:(\"FileSet\")"
    work_data = ActiveFedora::SolrService.get(query, rows: 1)['response']['docs'].first || {}
    Rails.logger.warn("No work found associated with alternate identifier: #{identifier}") if work_data.blank?
    self.resolve_admin_set_and_build_result(work_data, admin_set_title, identifier, :alternate_id)
  end
  def self.fetch_work_data_by_fileset_id(fileset_id, admin_set_title: nil)
    # Retrieve the work related to the fileset
    work_data = ActiveFedora::SolrService.get("file_set_ids_ssim:#{fileset_id}", rows: 1)['response']['docs'].first || {}
    Rails.logger.warn("No work found associated with fileset id: #{fileset_id}") if work_data.blank?
    self.resolve_admin_set_and_build_result(work_data, admin_set_title, fileset_id, :fileset_id)
  end
  def self.fetch_work_data_by_id(work_id, admin_set_title: nil)
    work_data = ActiveFedora::SolrService.get("id:#{work_id}", rows: 1)['response']['docs'].first || {}
    Rails.logger.warn("No work found associated with work id: #{work_id}") if work_data.blank?
    self.resolve_admin_set_and_build_result(work_data, admin_set_title, work_id)
  end

  def self.fetch_admin_set_by_title_or_id(admin_set_title: nil, admin_set_id: nil)
    return nil if admin_set_title.blank? && admin_set_id.blank?
    
    if admin_set_id.present?
      AdminSet.find(admin_set_id)
    else
      AdminSet.where(title: admin_set_title).first
    end
  rescue ActiveFedora::ObjectNotFoundError, ActiveRecord::RecordNotFound => e
    Rails.logger.warn("Admin set not found (title: #{admin_set_title}, id: #{admin_set_id}): #{e.message}")
    nil
  end

  def self.fetch_work_data_by_doi(doi, admin_set_title: nil)
    # Step 1: Exact match on doi_tesim
    query = "doi_tesim:\"#{doi}\""
    work_data = ActiveFedora::SolrService.get(query, rows: 1)['response']['docs'].first

    # Step 2: If that fails, normalize DOI and search identifier_tesim with wildcard
    if work_data.blank?
      normalized_doi = normalize_doi(doi)
      if normalized_doi
        fallback_value = "DOI: https://dx.doi.org/#{normalized_doi}"
        fallback_query = "identifier_tesim:\"#{fallback_value}\" NOT has_model_ssim:(\"FileSet\")"
        work_data = ActiveFedora::SolrService.get(fallback_query, rows: 1)['response']['docs'].first
      else
        Rails.logger.warn("Identifier does not appear to be a valid DOI: #{doi}. Ending search.")
        return nil
      end
    end
    if work_data.blank?
      Rails.logger.warn("No work found associated with doi: #{doi}")
      return nil
    end
    self.resolve_admin_set_and_build_result(work_data, admin_set_title, doi, :doi)
  end

  def self.generate_result_hash(work_data, admin_set_data, admin_set_title)
    identifiers = work_data['identifier_tesim'] || []

    pmid  = identifiers.find { |id| id.match?(/\APMID:\s*\d+/i) }&.split(':')&.last&.strip
    pmcid = identifiers.find { |id| id.match?(/\APMCID:\s*\S+/i) }&.split(':')&.last&.strip
    doi   = identifiers.find { |id| id.match?(/\ADOI:\s*\S+/i) }&.split(':', 2)&.last&.strip

    {
      work_id: work_data['id'],
      work_type: work_data.dig('has_model_ssim', 0),
      title: work_data['title_tesim']&.first,
      admin_set_id: admin_set_data['id'],
      admin_set_title: admin_set_data['title_tesim']&.first,
      file_set_ids: work_data['file_set_ids_ssim'],
      pmid: pmid,
      pmcid: pmcid,
      doi: doi
    }
  end

  def self.get_permissions_attributes(admin_set_id)
    # find admin set and manager groups for work
    manager_groups = Hyrax::PermissionTemplateAccess.joins(:permission_template)
                                                    .where(access: 'manage', agent_type: 'group')
                                                    .where(permission_templates: { source_id: admin_set_id })

    # find admin set and viewer groups for work
    viewer_groups = Hyrax::PermissionTemplateAccess.joins(:permission_template)
                                                   .where(access: 'view', agent_type: 'group')
                                                   .where(permission_templates: { source_id: admin_set_id })

    # update work permissions to give admin set managers edit access and viewer groups read access
    permissions_array = []
    manager_groups.each do |manager_group|
      permissions_array << { 'type' => 'group', 'name' => manager_group.agent_id, 'access' => 'edit' }
    end
    viewer_groups.each do |viewer_group|
      permissions_array << { 'type' => 'group', 'name' => viewer_group.agent_id, 'access' => 'read' }
    end

    permissions_array
  end
  
  def self.fetch_model_instance(work_type, work_id)
    raise ArgumentError, 'Both work_type and work_id are required' unless work_type.present? && work_id.present?

    work_type.constantize.find(work_id)
  rescue NameError, ActiveRecord::RecordNotFound => e
    Rails.logger.error("[WorkUtils] Failed to fetch model instance: #{e.message}")
    nil
  end

  def self.generate_cdr_url_for_alternate_id(identifier)
    generate_cdr_url(identifier: identifier)
  end

  def self.generate_cdr_url_for_work_id(work_id)
    generate_cdr_url(work_id: work_id)
  end

  def self.generate_cdr_url(work_id: nil, identifier: nil)
    raise ArgumentError, 'Provide either work_id or identifier' if work_id.blank? && identifier.blank?

    result =
      if work_id.present?
        self.fetch_work_data_by_id(work_id)
      else
        self.fetch_work_data_by_alternate_identifier(identifier)
      end

    if result.blank?
      return log_and_nil('No Solr record found', work_id: work_id, identifier: identifier)
    end

    resolved_work_id = result[:work_id].presence || work_id
    work_type = result[:work_type]

    return log_and_nil('Missing work_id', work_id: resolved_work_id, identifier: identifier) if resolved_work_id.blank?
    return log_and_nil('Missing work_type', work_id: resolved_work_id, identifier: identifier) if work_type.blank?

    build_cdr_url(work_type, resolved_work_id)
  rescue StandardError => e
    Rails.logger.warn("[CDR_URL] Failed (work_id=#{work_id.inspect}, identifier=#{identifier.inspect}): #{e.class}: #{e.message}")
    nil
  end

  # Only for when we have work_type + work_id from Solr and don’t want to use a Fedora object. Use Rails URL helpers for Fedora objects instead.
  def self.build_cdr_url(work_type, work_id)
    host = ENV['HYRAX_HOST'].presence or raise 'HYRAX_HOST not set'
    model = work_type.to_s.underscore.pluralize
    URI.join(host, "/concern/#{model}/#{work_id}").to_s
  end

  def self.log_and_nil(msg, **ctx)
    Rails.logger.warn("[CDR_URL] #{msg} #{ctx.compact}")
    nil
  end

  def self.resolve_admin_set_and_build_result(work_data, admin_set_title, context_id, concern = :id)
    return nil if work_data.blank?

    admin_set_title ||= work_data['admin_set_tesim']&.first
    admin_set_data = admin_set_title ? ActiveFedora::SolrService.get(
      "title_tesim:#{admin_set_title} AND has_model_ssim:(\"AdminSet\")",
      :rows => 1, 'df' => 'title_tesim'
    )['response']['docs'].first : {}

    Rails.logger.warn(generate_warning_message(admin_set_title, context_id, concern)) if admin_set_data.blank?
    result = generate_result_hash(work_data, admin_set_data, admin_set_title)
    # No work_id means no valid result
    result if result[:work_id].present?
  end

  def self.generate_warning_message(admin_set_title, id, concern = :id)
    if admin_set_title.blank?
      logged_concern = 'id'
      case concern
      when :doi
        logged_concern = 'doi'
      when :fileset
        logged_concern = 'fileset id'
      end
      return "Could not find an admin set, the work with #{logged_concern}: #{id} has no admin set name."
    else
      return "No admin set found with title_tesim: #{admin_set_title}."
    end
  end

  def self.normalize_doi(identifier)
    return identifier unless identifier.is_a?(String)
    # Strip prefix if it's a full DOI URL
    if identifier.match?(%r{\Ahttps?://(dx\.)?doi\.org/}i)
      return identifier.strip.sub(%r{\Ahttps?://(dx\.)?doi\.org/}i, '')
    elsif identifier.match?(/\A10\.\d{4,9}/) && identifier.include?('/')
      return identifier.strip
    else
      return nil
    end
  end

  # Wrapper to find best work match by trying each alternate identifier in order
  def self.find_best_work_match_by_alternate_id(doi: nil, pmcid: nil, pmid: nil)
    alt_ids = { doi: doi, pmcid: pmcid, pmid: pmid }.compact
    return nil if alt_ids.empty?

    alt_ids.each do |key, id|
      next if id.blank?

      work_data =
        case key.to_s
        when 'doi'
          WorkUtilsHelper.fetch_work_data_by_doi(id)
        else
          WorkUtilsHelper.fetch_work_data_by_alternate_identifier(id)
        end

      return work_data if work_data.present?
    end

    nil
  end

  private_class_method :build_cdr_url, :log_and_nil, :generate_warning_message
end
