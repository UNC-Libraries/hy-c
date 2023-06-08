# frozen_string_literal: true
module Tasks
  class DoiCreateService
    include HycHelper

    # From page 38 https://schema.datacite.org/meta/kernel-4.2/doc/DataCite-MetadataKernel_v4.2.pdf
    DCMI_TO_DATACITE_TYPE = {
      'MovingImage' => 'Audiovisual',
      'Collection' => 'Collection',
      'Dataset' => 'Dataset',
      'Event' => 'Event',
      'StillImage' => 'Image',
      'Image' => 'Image',
      'InteractiveResource' => 'InteractiveResource',
      'PhysicalObject' => 'PhysicalObject',
      'Service' => 'Service',
      'Software' => 'Software',
      'Sound' => 'Sound',
      'Text' => 'Text'
    }

    RESOURCE_TYPE_TO_DATACITE = {
      '3D Object' => 'InteractiveResource',
      'Art' => 'Other',
      'Article' => 'Text',
      'Audio' => 'Sound',
      'Book' => 'Text',
      'Capstone Project' => 'Other',
      'Conference Proceeding' => 'Text',
      'Dataset' => 'Dataset',
      'Dissertation' => 'Text',
      'Educational Resource' => 'Other',
      'Honors Thesis' => 'Text',
      'Image' => 'Image',
      'Journal' => 'Text',
      'Journal Item' => 'Text',
      'Map or Cartographic Material' => 'Image',
      'Masters Paper' => 'Text',
      'Masters Thesis' => 'Text',
      'Newsletter' => 'Text',
      'Other' => 'Other',
      'Part of Book' => 'Text',
      'Poster' => 'Text',
      'Presentation' => 'Text',
      'Project' => 'Other',
      'Report' => 'Text',
      'Research Paper' => 'Text',
      'Software or Program Code' => 'Software',
      'Undergraduate Thesis' => 'Text',
      'Video' => 'Audiovisual',
      'Working Paper' => 'Text'
    }

    def initialize(rows = 1000)
      @rows = rows
      use_test_api = ENV['DATACITE_USE_TEST_API'].to_s.downcase == 'true'
      @doi_prefix = ENV['DATACITE_PREFIX']
      if use_test_api
        @doi_creation_url = 'https://api.test.datacite.org/dois'
        @doi_url_base = 'https://handle.test.datacite.org'
      else
        @doi_creation_url = 'https://api.datacite.org/dois'
        @doi_url_base = 'https://doi.org'
      end
      @doi_user = ENV['DATACITE_USER']
      @doi_password = ENV['DATACITE_PASSWORD']
    end

    def doi_request(data, retries = 2)
      HTTParty.post(@doi_creation_url,
                    headers: { 'Content-Type' => 'application/vnd.api+json' },
                    basic_auth: {
                      username: @doi_user,
                      password: @doi_password
                    },
                    body: data
                   )
    rescue Net::ReadTimeout, Net::OpenTimeout => e
      if retries.positive?
        retries -= 1
        puts "#{get_time} Timed out while attempting to create DOI using #{@doi_creation_url}, retrying with #{retries} retries remaining."
        sleep(30)
        doi_request(data, retries)
      else
        raise e
      end
    end

    def format_data(work)
      data = {
        data: {
          type: 'dois',
          attributes: {
            prefix: @doi_prefix,
            titles: [{ title: work[:title].first }],
            types: parse_resource_type(work[:dcmi_type], work[:resource_type]),
            url: get_work_url(work.class, work.id),
            event: 'publish',
            schemaVersion: 'http://datacite.org/schema/kernel-4'
          }
        }
      }

      #########################
      #
      # Required fields
      #
      #########################
      creators = parse_people(work, 'creators')
      data[:data][:attributes][:creators] = if creators.blank?
                                              {
                                                name: 'The University of North Carolina at Chapel Hill University Libraries',
                                                nameType: 'Organizational'
                                              }
                                            else
                                              creators
                                            end

      publisher = parse_field(work, 'publisher')
      data[:data][:attributes][:publisher] = if publisher.blank?
                                               'The University of North Carolina at Chapel Hill University Libraries'
                                             else
                                               publisher.first
                                             end

      publication_year = parse_field(work, 'date_issued')
      data[:data][:attributes][:publicationYear] = if publication_year.blank?
                                                     Date.today.year
                                                   else
                                                     Array.wrap(publication_year).first.to_s.match(/\d{4}/)[0]
                                                   end

      ############################
      #
      # Optional fields
      #
      ############################
      contributors = parse_people(work, 'contributors')
      data[:data][:attributes][:contributors] = contributors unless contributors.blank?

      description = parse_description(work, 'abstract')
      data[:data][:attributes][:descriptions] = description unless description.blank?

      funding = parse_funding(work, 'funder')
      data[:data][:attributes][:fundingReferences] = funding unless funding.blank?

      language = parse_field(work, 'language').first
      if language.present?
        lang_code = LanguagesService.iso639_1(language)
        data[:data][:attributes][:language] = lang_code unless lang_code.blank?
      end

      rights = parse_field(work, 'rights_statement')
      unless rights.blank?
        rights_uri = Array.wrap(rights).first
        rights_label = CdrRightsStatementsService.label(rights_uri)
        data[:data][:attributes][:rightsList] = { rights: rights_label, rightsUri: rights_uri }
      end

      sizes = parse_field(work, 'extent')
      data[:data][:attributes][:sizes] = sizes unless sizes.blank?

      subjects = parse_subjects(work, 'subject')
      data[:data][:attributes][:subjects] = subjects unless subjects.blank?

      data.to_json
    end

    def create_doi(record)
      puts "#{get_time} Creating DOI for #{record['id']}"
      work = ActiveFedora::Base.find(record['id'])
      record_data = format_data(work)
      response = doi_request(record_data)

      if response.success?
        doi = JSON.parse(response.body)['data']['id']
        full_doi = "#{@doi_url_base}/#{doi}"
        work.update!(doi: full_doi)

        puts "#{get_time} DOI created for record #{record['id']}: #{full_doi}"
      else
        puts "#{get_time} ERROR: Unable to create DOI for record #{record['id']}. Reason: \"#{response}\""
      end

      sleep(2)
    end

    def create_batch_doi
      start_time = Time.now
      records = ActiveFedora::SolrService.get('visibility_ssi:open AND -doi_tesim:* AND workflow_state_name_ssim:deposited AND has_model_ssim:(Article Artwork DataSet Dissertation General HonorsThesis Journal MastersPaper Multimed ScholarlyWork)',
                                              rows: @rows,
                                              sort: 'system_create_dtsi ASC',
                                              fl: 'id')['response']['docs']

      if records.length.positive?
        puts "#{get_time} Preparing to add DOIs to #{records.length} records"
        records.each do |record|
          create_doi(record)
        end
        puts "#{get_time} Added #{records.length} DOIs in #{Time.now - start_time}s"
        records.length
      else
        puts "#{get_time} There are no records that need to have DOIs added."
        0
      end
    rescue StandardError => e
      puts "#{get_time} There was an error creating dois: #{e.message}"
      -1
    end

    private

    def get_time
      Time.new.to_s
    end

    def get_values(record_field, process_method)
      values = []

      values = process_method.call(record_field) unless record_field.blank?

      values
    end

    def parse_field(record, field)
      record.attributes.keys.member?(field) ? record[field.to_sym] : []
    end

    # Field uses a controlled vocabulary
    def parse_resource_type(dcmi_type, record_type)
      result = {}

      datacite_type = nil
      if !dcmi_type.blank?
        # Prioritize the "text" type when multiple are present
        dcmi_val = if dcmi_type.include?('http://purl.org/dc/dcmitype/Text')
                     'http://purl.org/dc/dcmitype/Text'
                   else
                     dcmi_type.first
                   end
        dcmi_type_term = dcmi_val.split('/').last
        datacite_type = DCMI_TO_DATACITE_TYPE[dcmi_type_term]
      else
        # Fall back to resource type mapping
        resource_type = record_type&.first
        datacite_type = RESOURCE_TYPE_TO_DATACITE[resource_type]
      end
      if datacite_type.nil?
        puts "#{get_time} WARNING: Unable to determine resourceTypeGeneral for record" if datacite_type.nil?
        datacite_type = 'Text'
      end
      
      # Storing the datacite type. If it is nil or invalid, datacite will reject the creation
      result[:resourceTypeGeneral] = datacite_type

      if record_type.present?
        result[:resourceType] = record_type.first unless record_type.blank?
      else
        result[:resourceType] = datacite_type
      end

      result
    end

    def parse_funding(record, field)
      if record.attributes.keys.member?(field)
        formatted_values = ->(work) {
          work.map do |f|
            { funderName: f }
          end
        }
        get_values(record["#{field}"], formatted_values)
      end
    end

    def parse_subjects(record, field)
      if record.attributes.keys.member?(field)
        formatted_values = ->(work) {
          work.map do |s|
            { subject: s }
          end
        }
        get_values(record["#{field}"], formatted_values)
      end
    end

    def parse_description(record, field)
      if record.attributes.keys.member?(field)
        formatted_values = ->(work) { work.map { |d| { description: d, descriptionType: 'Abstract' } } }
        get_values(record["#{field}"], formatted_values)
      end
    end

    def parse_people(work, person_field)
      return [] unless work.attributes.keys.member?(person_field)

      people = []

      work[person_field].each do |p|
        p_json = JSON.parse(p.to_json)
        person = { name: p_json['name'].first, nameType: 'Personal' }

        affil = p_json['affiliation']&.first
        other_affil = p_json['other_affiliation']&.first

        if !affil.blank?
          expanded_affils = DepartmentsService.term(affil)
          person[:affiliation] = expanded_affils.split('; ') unless expanded_affils.nil?
        elsif !other_affil.blank?
          person[:affiliation] = [other_affil]
        end

        orcid = p_json['orcid']&.first
        person[:nameIdentifiers] = [nameIdentifier: orcid, nameIdentifierScheme: 'ORCID'] unless orcid.blank?

        people << person
      end

      people
    end
  end
end
