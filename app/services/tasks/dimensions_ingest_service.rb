# frozen_string_literal: true
module Tasks
  require 'tasks/migration_helper'
  class DimensionsIngestService
    attr_reader :admin_set, :depositor

    class DimensionsPublicationIngestError < StandardError
    end

    def initialize(config)
      @config = config
      # Should deposit works into an admin set
      admin_set_title = @config['admin_set']
      @admin_set = ::AdminSet.where(title: admin_set_title)&.first
      raise(ActiveRecord::RecordNotFound, "Could not find AdminSet with title #{admin_set_title}") unless @admin_set.present?

      @depositor = User.find_by(uid: @config['depositor_onyen'])
      raise(ActiveRecord::RecordNotFound, "Could not find User with onyen #{@config['depositor_onyen']}") unless @depositor.present?
    end
   
    def ingest_publications(publications)
      puts "[#{Time.now}] Ingesting publications from Dimensions."
      ingested_count = 0

      publications.each.with_index do |publication, index|
        begin
        # WIP: Remove Index Break Later
          if index == 3
            break
          end
          article_with_metadata = article_with_metadata(publication)
          # create_sipity_workflow(work: article_with_metadata)
          pdf_path = extract_pdf(publication)
          pdf_file = attach_pdf_to_work(article_with_metadata, pdf_path)

          pdf_file.update permissions_attributes: group_permissions

          ingested_count += 1
          rescue StandardError => e
            raise DimensionsPublicationIngestError, "Error ingesting publication: #{e.message}"
        end
      end
      ingested_count
    end

    def article_with_metadata(publication)
      article = Article.new
      populate_article_metadata(article, publication)
      puts "Article Inspector: #{article.inspect}"
      article.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
      article.permissions_attributes = group_permissions
      article.save!
      article
    end

    def group_permissions
      @group_permissions ||= MigrationHelper.get_permissions_attributes(@admin_set.id)
    end

        # def create_sipity_workflow(work:)
    #   # Create sipity record
    #   join = Sipity::Workflow.joins(:permission_template)
    #   workflow = join.where(permission_templates: { source_id: work.admin_set_id }, active: true)
    #   raise(ActiveRecord::RecordNotFound, "Could not find Sipity::Workflow with permissions template with source id #{work.admin_set_id}") unless workflow.present?

    #   workflow_state = Sipity::WorkflowState.where(workflow_id: workflow.first.id, name: 'deposited')
    #   raise(ActiveRecord::RecordNotFound, "Could not find Sipity::WorkflowState with workflow_id: #{workflow.first.id} and name: 'deposited'") unless workflow_state.present?

    #   Sipity::Entity.create!(proxy_for_global_id: work.to_global_id.to_s,
    #                          workflow: workflow.first,
    #                          workflow_state: workflow_state.first)
    # end

    def populate_article_metadata(article, publication)
      set_basic_attributes(article, publication)
      set_journal_attributes(article, publication)
      set_rights_and_types(article, publication)
    end

    def set_basic_attributes(article, publication)
      article.title = [publication['title']]
      article.admin_set = @admin_set
      article.creators_attributes = publication['authors'].map.with_index { |author, index| [index,author_to_hash(author, index)] }.to_h
      article.funder = format_funders_data(publication)
      article.date_issued = publication['date']
      article.abstract = [publication['abstract']].compact.presence
      article.resource_type = [publication['type']].compact.presence
      article.publisher = [publication['publisher']].compact.presence
    end

    def set_rights_and_types(article, publication)
      article.rights_statement = CdrRightsStatementsService.label('http://rightsstatements.org/vocab/InC/1.0/')
      article.dcmi_type = [DcmiTypeService.label('http://purl.org/dc/dcmitype/Text')]
      article.edition = determine_edition(publication)
    end

    def set_journal_attributes(article, publication)
      article.journal_title = publication['journal_title_raw'].presence
      article.journal_volume = publication['volume'].presence
      article.journal_issue = publication['issue'].presence
      article.page_start, article.page_end = parse_page_numbers(publication).values_at(:start, :end)
    end

    def set_identifiers(article, publication)
      article.identifier = format_publication_identifiers(publication)
      article.issn = publication['issn'].presence
    end
  

    def author_to_hash(author, index)
      hash = {
        'name' => "#{[author['first_name'], author['last_name']].compact.join(' ')}",
        'orcid' => author['orcid'].present? ? author['orcid'] : '',
        'index' => (index + 1).to_s,
      }
      # Splitting author affiliations into UNC and other affiliations and adding them to hash
      if author['affiliations'].present?
        unc_grid_id = 'grid.410711.2'
        author_unc_affiliation = author['affiliations'].select { |affiliation| affiliation['id'] == unc_grid_id || 
                                                                  affiliation['raw_affiliation'].include?('UNC') ||
                                                                  affiliation['raw_affiliation'].include?('University of North Carolina, Chapel Hill')}.first
        author_other_affiliations = author['affiliations'].reject { |affiliation| affiliation['id'] == unc_grid_id || 
                                                                  affiliation['raw_affiliation'].include?('UNC') ||
                                                                  affiliation['raw_affiliation'].include?('University of North Carolina, Chapel Hill')}
        hash['other_affiliation'] = author_other_affiliations.map { |affiliation| affiliation['raw_affiliation'] }
        hash['affiliation'] = author_unc_affiliation.present? ? author_unc_affiliation['raw_affiliation'] : ''
      end
      hash
    end

    def format_publication_identifiers(publication)
      [
        publication['id'].present? ? "Dimensions ID: #{publication['id']}" : nil,
        publication['doi'].present? ? "DOI: https://dx.doi.org/#{publication['doi']}" : nil,
        publication['pmid'].present? ? "PMID: #{publication['pmid']}" : nil,
        publication['pmcid'].present? ? "PMCID: #{publication['pmcid']}" : nil,
      ].compact
    end

    def format_funders_data(publication)
      publication['funders'].presence&.map do |funder|
        funder.map { |key, value| "#{key}: #{value}" if value.present? }.compact.join('||')
      end
    end

    def parse_page_numbers(publication)
      return { start: nil, end: nil } unless publication['pages'].present?
      
      pages = publication['pages'].split('-')
      {
        start: pages.first,
        end: (pages.length == 2 ? pages.last : nil)
      }
    end

    def determine_edition(publication)
      publication['type'].present? && publication['type'] == 'preprint' ? 'preprint' : nil
    end

    def extract_pdf(publication)
      pdf_url = publication['linkout']
      return nil unless pdf_url.present?
      
      response = HTTParty.head(pdf_url)
      return nil unless response.headers['content-type'].include?('application/pdf')

      pdf_file = Tempfile.new(['temp_pdf', '.pdf'])
      pdf_file.binmode
      pdf_file.write(HTTParty.get(pdf_url).body)
      pdf_file.rewind
      
      file_path = pdf_file.path
      pdf_file.close  
      file_path  # Return the file path
    end


    def attach_pdf_to_work(work, file_path)
      attach_file_set_to_work(work: work, file_path: file_path, user: @depositor, visibility: work.visibility)
    end

    def attach_file_set_to_work(work:, file_path:, user:, visibility:)
      file_set_params = { visibility: visibility }
      @logger.info("Attaching file_set for #{file_path} to DOI: #{work.identifier.first}")
      file_set = FileSet.create
      actor = Hyrax::Actors::FileSetActor.new(file_set, user)
      actor.create_metadata(file_set_params)
      file = File.open(file_path)
      actor.create_content(file)
      actor.attach_to_work(work, file_set_params)
      file.close

      file_set
    end



  

  end
    end
