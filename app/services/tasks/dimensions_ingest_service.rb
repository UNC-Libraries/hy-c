# frozen_string_literal: true
module Tasks
  require 'tasks/ingest_helper'
  class DimensionsIngestService
    include Tasks::IngestHelper
    attr_reader :admin_set, :depositor

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
      time = Time.now
      Rails.logger.info("[#{time}] Ingesting publications from Dimensions.")
      puts "[#{time}] Ingesting publications from Dimensions."
      # WIP Notes
      # Articles marked for review and normal ones in the ingested array
      # Failed, attach the error? (Just put it in the logs)
      # Account for different errors in rescue
      res = {ingested: [], failed: [], time: time}

      publications.each.with_index do |publication, index|
        begin
        # WIP: Remove Index Break Later
          # if index == 3
          #   break
          # end
          process_publication(publication)
          res[:ingested] << publication
          rescue StandardError => e
            res[:failed] << { publication: publication, error: e.message }
            Rails.logger.error("Error ingesting publication '#{publication['title']}': #{e.message}")
            # raise DimensionsPublicationIngestError, error_message
        end
      end
      res
    end

    def process_publication(publication)
      article = article_with_metadata(publication)
      create_sipity_workflow(work: article)
      pdf_path = extract_pdf(publication)

      if pdf_path
        pdf_file = attach_pdf_to_work(article, pdf_path, @depositor)
        pdf_file.update(permissions_attributes: group_permissions(@admin_set))
        File.delete(pdf_path) if File.exist?(pdf_path)
      end
    end

    def article_with_metadata(publication)
      article = Article.new
      populate_article_metadata(article, publication)
      # puts "Article Inspector: #{article.inspect}"
      article.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
      article.permissions_attributes = group_permissions(@admin_set)
      article.save!
      article
    end

    def populate_article_metadata(article, publication)
      set_basic_attributes(article, publication)
      set_journal_attributes(article, publication)
      set_rights_and_types(article, publication)
    end

    def set_basic_attributes(article, publication)
      article.title = [publication['title']]
      article.admin_set = @admin_set
      article.creators_attributes = publication['authors'].map.with_index { |author, index| [index, author_to_hash(author, index)] }.to_h
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
                                                                  affiliation['raw_affiliation'].include?('University of North Carolina, Chapel Hill')
        }.first
        author_other_affiliations = author['affiliations'].reject { |affiliation| affiliation['id'] == unc_grid_id ||
                                                                  affiliation['raw_affiliation'].include?('UNC') ||
                                                                  affiliation['raw_affiliation'].include?('University of North Carolina, Chapel Hill')
        }
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
      pdf_url = publication && publication['linkout']? publication['linkout'] : nil
      unless publication && publication['linkout']
        no_linkout_message = 'Failed to retrieve PDF. Publication does not have a linkout URL.'
        nil_message = 'Failed to retrieve PDF. Publication is nil.'
        Rails.logger.error(publication.present? ? no_linkout_message : nil_message)
        return nil
      end
      begin
        response = HTTParty.head(pdf_url)
        raise 'Incorrect content type.' unless response.headers['content-type'] && response.headers['content-type'].include?('application/pdf')
        pdf_response = HTTParty.get(pdf_url)
        raise "Failed to download PDF: HTTP status #{pdf_response.code}" unless pdf_response.code == 200

        storage_dir = ENV['TEMP_STORAGE']
        filename = "downloaded_pdf_#{Time.now.to_i}.pdf"
        file_path = File.join(storage_dir, filename)

        # puts "Saving PDF #{filename} to: #{file_path}"
        File.open(file_path, 'wb') { |file| file.write(pdf_response.body) }
        file_path  # Return the file path
      rescue StandardError => e
        Rails.logger.error("Failed to retrieve PDF from #{pdf_url}: #{e.message}")
        nil
      end
    end

  end
    end
