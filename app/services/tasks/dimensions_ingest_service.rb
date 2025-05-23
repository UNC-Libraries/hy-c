# frozen_string_literal: true
module Tasks
  require 'tasks/ingest_helper'
  class DimensionsIngestService
    include Tasks::IngestHelper
    attr_reader :admin_set, :depositor
    UNC_GRID_ID = 'grid.410711.2'

    def initialize(config)
      @config = config
      admin_set_title = @config['admin_set']
      @download_delay = @config['download_delay'] || 2
      @wiley_tdm_api_token = @config['wiley_tdm_api_token']
      @admin_set = ::AdminSet.where(title: admin_set_title)&.first
      raise(ActiveRecord::RecordNotFound, "Could not find AdminSet with title #{admin_set_title}") unless @admin_set.present?

      @depositor = User.find_by(uid: @config['depositor_onyen'])
      raise(ActiveRecord::RecordNotFound, "Could not find User with onyen #{@config['depositor_onyen']}") unless @depositor.present?
    end

    def ingest_publications(publications)
      time = Time.now
      Rails.logger.info('Ingesting publications from Dimensions.')
      res = {ingested: [], failed: [], time: time, admin_set_title: @admin_set.title.first, depositor: @config['depositor_onyen']}

      publications.each.with_index do |publication, index|
        begin
          next unless publication.presence
          article = process_publication(publication)
          res[:ingested] << publication.merge('article_id' => article.id)
          rescue StandardError => e
            publication.delete('pdf_attached')
            res[:failed] << publication.merge('error' => [e.class.to_s, e.message])
            Rails.logger.error("Error ingesting publication '#{publication['title']}' with Dimensions ID: #{publication['id']}")
            Rails.logger.error [e.class.to_s, e.message, *e.backtrace].join($RS)
        end
      end
      res
    end

    def process_publication(publication)
      article = article_with_metadata(publication)
      create_sipity_workflow(work: article)
      pdf_path = extract_pdf(publication)
      if pdf_path
        pdf_file = attach_pdf_to_work(article, pdf_path, @depositor, article.visibility)
        pdf_file.update(permissions_attributes: group_permissions(@admin_set))
      end
      article
    end

    def article_with_metadata(publication)
      article = Article.new
      populate_article_metadata(article, publication)
      article.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
      article.permissions_attributes = group_permissions(@admin_set)
      article.save!
      article
    end

    def populate_article_metadata(article, publication)
      set_basic_attributes(article, publication)
      set_journal_attributes(article, publication)
      set_rights_and_types(article, publication)
      set_identifiers(article, publication)
    end

    def set_basic_attributes(article, publication)
      article.title = [publication['title']]
      article.admin_set = @admin_set
      article.depositor = @config['depositor_onyen']
      article.creators_attributes = publication['authors'].map.with_index { |author, index| [index, author_to_hash(author, index)] }.to_h
      article.funder = publication['funders']&.map { |funder| funder['name'] }
      article.date_issued = publication['date']
      article.abstract = [publication['abstract']].compact.presence || ['N/A']
      article.resource_type = ['Article']
      article.publisher = [publication['publisher']].compact.presence
      article.keyword = publication['concepts']
    end

    def set_rights_and_types(article, publication)
      rights_statement = 'http://rightsstatements.org/vocab/InC/1.0/'
      article.rights_statement = rights_statement
      article.rights_statement_label = CdrRightsStatementsService.label(rights_statement)
      article.dcmi_type = ['http://purl.org/dc/dcmitype/Text']
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
        'name' => "#{[author['last_name'], author['first_name']].compact.join(', ')}",
        'orcid' => author['orcid'].present? ? "https://orcid.org/#{author['orcid'].first}" : '',
        'index' => (index + 1).to_s,
      }
      # Add first author affiliation to other affiliation array
      if author['affiliations'].present?
        hash['other_affiliation'] = retrieve_author_affiliation(author['affiliations'])
      end
      hash
    end

    def retrieve_author_affiliation(affiliations)
      unc_affiliations = affiliations.select { |affiliation| affiliation['id'] == UNC_GRID_ID }
      if !unc_affiliations.empty?
        # Prioritize UNC affiliations, only retrieving the first one
        return unc_affiliations[0]['raw_affiliation']
      end
      # Otherwise, retrieve the first affiliation
      return affiliations[0]['raw_affiliation']
    end


    def format_publication_identifiers(publication)
      [
        publication['id'].present? ? "Dimensions ID: #{publication['id']}" : nil,
        publication['doi'].present? ? "DOI: https://dx.doi.org/#{publication['doi']}" : nil,
        publication['pmid'].present? ? "PMID: #{publication['pmid']}" : nil,
        publication['pmcid'].present? ? "PMCID: #{publication['pmcid']}" : nil,
      ].compact
    end

    def parse_page_numbers(publication)
      return { start: nil, end: nil } unless publication['pages'].present?

      pages = publication['pages'].split('-')
      {
        start: pages.first,
        end: (pages.length == 2 ? pages.last : nil)
      }
    end

    def extract_pdf(publication)
      pdf_url = publication['linkout'] ? publication['linkout'] : nil
      # Set pdf_attached to false by default
      publication['pdf_attached'] = false
      headers = {}

      unless pdf_url
        Rails.logger.warn('Failed to retrieve PDF. Publication does not have a linkout URL.')
        return nil
      end
      # Use the Wiley Online Library text data mining API to retrieve the PDF if it's a Wiley publication
      if pdf_url.include?('hindawi.com') || pdf_url.include?('wiley.com')
        Rails.logger.info('Detected a Wiley affiliated publication, attempting to retrieve PDF with their API.')
        encoded_doi = URI.encode_www_form_component(publication['doi'])
        encoded_url = "https://api.wiley.com/onlinelibrary/tdm/v1/articles/#{encoded_doi}"
        headers['Wiley-TDM-Client-Token'] = "#{@wiley_tdm_api_token}"
      else
        # Use the encoded linkout URL from dimensions otherwise
        encoded_url = URI::DEFAULT_PARSER.escape(pdf_url)
      end
      download_pdf(encoded_url, publication, headers)
    end

    def download_pdf(encoded_url, publication, headers)
      begin
        # Enforce a delay before making the request
        sleep @download_delay
        # Assume API URLs are valid and skip the content type check to avoid rate limiting
        if !is_api(encoded_url)
          # Verify the content type of the PDF before downloading
          response = HTTParty.head(encoded_url, headers: headers)
          if response.code == 200
            # Log a warning if the content type is not a PDF
            raise "Incorrect content type: '#{response.headers['content-type']}'" unless response.headers['content-type']&.include?('application/pdf')
          else
            # Log a warning if the response code is not 200
            Rails.logger.warn("Received a non-200 response code (#{response.code}) when making a HEAD request to the PDF URL: #{encoded_url}")
          end
        else
          Rails.logger.info("Skipping content type check for API URL: #{encoded_url}")
        end
        # Attempt to retrieve the PDF from the encoded URL
        pdf_response = HTTParty.get(encoded_url, headers: headers)
        if pdf_response.code != 200
          wiley_rate_exceeded = headers.keys.include?('Wiley-TDM-Client-Token') && pdf_response&.body.match?(/rate/i)
            # Retry the request after a delay if the Wiley-TDM API rate limit is exceeded
          if wiley_rate_exceeded
            delay_time = @download_delay * 15
            Rails.logger.warn("Wiley-TDM API rate limit exceeded. Retrying request in #{delay_time} seconds.")
            # Retry the request after a delay if the Wiley-TDM API rate limit is exceeded
            sleep delay_time
            pdf_response = HTTParty.get(encoded_url, headers: headers)
          end

            # If the second attempt also fails, or if there's another error, raise an error
          if pdf_response.code != 200
            e_message = "Failed to download PDF: HTTP status '#{pdf_response.code}'"
            # Include specific error message for potential Wiley-TDM API rate limiting (pdf_response.code != 200 and the Wiley API response body mentions rate limiting)
            e_message += ' (Exceeded Wiley-TDM API rate limit)' if wiley_rate_exceeded
            raise e_message
          end
        end
        raise "Incorrect content type: '#{pdf_response.headers['content-type']}'" unless pdf_response.headers['content-type']&.include?('application/pdf')

        # Generate a unique filename for the PDF and save it to the temporary storage directory
        storage_dir = ENV['TEMP_STORAGE']
        time_stamp = Time.now.strftime('%Y%m%d%H%M%S%L')
        filename = "downloaded_pdf_#{time_stamp}.pdf"
        file_path = File.join(storage_dir, filename)

        # Write the PDF to the file system and mark the publication as having a PDF attached
        File.open(file_path, 'wb') { |file| file.write(pdf_response.body) }
        publication['pdf_attached'] = true
        file_path  # Return the file path
      rescue StandardError => e
        Rails.logger.error("Failed to retrieve PDF from URL '#{encoded_url}'. #{e.message}")
        nil
      end
    end

    def is_api(encoded_url)
      encoded_url.include?('api')
    end
  end
end
