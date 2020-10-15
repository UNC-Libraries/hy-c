module Tasks
  require 'roo'
  require 'tasks/migrate/services/progress_tracker'
  require 'tasks/migration_helper'

  class OnescienceIngestService

    attr_reader :config

    # scopus afid 60025111 = The University of North Carolina at Chapel Hill
    # scopus afid 60020469 = UNC School of Medicine
    # scopus afid 60072681 = UNC Project-Malawi
    # scopus afid 113885172 = UNC Project-China
    # scopus afid 60013450 = UNC school of dentistry
    # scopus afid 60005053 = Carolina Population Center
    # scopus afid 60122501 = UNC business school
    UNC_SCOPUS_AFIDS = (%w'60025111 60020469 60072681 113885172 60013450 60005053 60122501')

    def initialize(args)
      @config = YAML.load_file(args[:configuration_file])
    end

    def ingest
      # config file with worktype, adminset, depositor, mount location
      puts "[#{Time.now}] Start ingest of onescience articles in #{@config['metadata_file']}"

      # set visibility variables
      vis_private = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
      vis_public = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC

      @admin_set_id = ::AdminSet.where(title: @config['admin_set']).first.id
      @depositor_onyen = @config['depositor_onyen']

      load_data
      puts "[#{Time.now}] loaded onescience data"
      create_deposit_record
      puts "[#{Time.now}] created deposit record for batch"

      # Progress tracker for objects migrated
      @object_progress = Migrate::Services::ProgressTracker.new(@config['progress_log'])
      @skipped_objects = Migrate::Services::ProgressTracker.new(@config['skipped_log'])
      already_ingested = @object_progress.completed_set + @skipped_objects.completed_set
      puts "Skipping #{already_ingested.length} previously ingested and skipped works"

      count = @data.count
      # extract needed metadata and create articles
      @data.each_with_index do |item_data, index|
        puts '',"[#{Time.now}] ingesting #{item_data['onescience_id']} (#{index+1} of #{count})"

        # Skip this item if it has been ingested before
        if already_ingested.include?(item_data['onescience_id'])
          puts "Skipping previously ingested #{item_data['onescience_id']}"
          next
        end

        # skip if article already exists in the cdr
        if item_data['Is bibliographic data in IR'] != 'No'
          puts "[#{Time.now}] Article is already in the CDR: #{item_data['onescience_id']}"
          next
        end
        work_attributes, files = parse_onescience_metadata(item_data)

        work = @config['work_type'].singularize.classify.constantize.new
        work.depositor = @depositor_onyen

        work = MigrationHelper.check_enumeration(work_attributes, work, item_data['onescience_id'])

        # Check for embargo data
        embargo_term = @embargo_mapping.find{ |e| e['onescience_id'] = item_data['onescience_id'] }
        visibility = vis_public
        embargo_release_date = nil
        if !embargo_term.blank?
          months = embargo_term['Embargo'][/\d+/].to_i
          original_embargo_release_date = Date.parse(work_attributes['date_issued']+'-01-01') + (months).months
          if original_embargo_release_date.future?
            visibility = vis_private
            embargo_release_date = original_embargo_release_date
          end
        end

        work.visibility = visibility
        if !embargo_release_date.blank?
          work.embargo_release_date = embargo_release_date
          work.visibility_during_embargo = vis_private
          work.visibility_after_embargo = vis_public
        end

        # only save works with files
        work_saved = false

        # attach pdfs from folder on p-drive
        if !files.blank?
          puts "[#{Time.now}] #{item_data['onescience_id']} attaching files"
          sources = []
          file_count = files.count
          attached_file_count = 0

          # Move pubmed file to beginning of hash so it will be the primary work
          if files.key?('PubMedCentral-Link_Files')
            files = {'PubMedCentral-Link_Files' => files['PubMedCentral-Link_Files']}.merge(files)
          end

          files.each_with_index do |(source_name,file_id),file_index|
            puts "[#{Time.now}] #{item_data['onescience_id']} attaching file #{file_index+1} of #{file_count}"
            source_url = item_data[source_name.chomp('_Files')]
            if sources.include?(file_id)
              puts "[#{Time.now}] #{item_data['onescience_id']} skipping duplicate file: #{file_id}"
              next
            else
              sources << file_id
            end

            file_visibility = vis_private

            # set pubmed central or first listed file as public
            if (file_index == 0 && !files.key?('PubMedCentral-Link_Files')) || (source_name.include? 'PubMedCentral-Link')
              file_visibility = vis_public
            end

            # parse filename
            if source_name.include? 'PubMedCentral-Link'
              filename = "PubMedCentral-#{source_url.split('articles/').last.split('/').first}.pdf"
            elsif source_name.include? 'EuropePMC-Link'
              filename = "EuropePMC-#{source_url.split('accid=').last.split('&').first}.pdf"
            else
              if source_url.match(/.*\/[a-zA-Z0-9._-]*\.pdf$/)
                filename = source_url.split('/').last
              else
                puts "[#{Time.now}] #{item_data['onescience_id']} nonstandard source url: #{source_url}"
                filename = "#{file_id}.pdf"
              end
            end

            pdf_location = @pdf_files.select { |path| path.include? file_id }.first
            if !pdf_location.blank? # can we find the file
              # save work if it has at least one file
              if !work_saved
                work.save!
                puts "[#{Time.now}] #{item_data['onescience_id']},#{work.id} saved new article"

                work.update permissions_attributes: MigrationHelper.get_permissions_attributes(@admin_set_id)

                # Create sipity record
                workflow = Sipity::Workflow.joins(:permission_template)
                               .where(permission_templates: { source_id: work.admin_set_id }, active: true)
                workflow_state = Sipity::WorkflowState.where(workflow_id: workflow.first.id, name: 'deposited')
                Sipity::Entity.create!(proxy_for_global_id: work.to_global_id.to_s,
                                       workflow: workflow.first,
                                       workflow_state: workflow_state.first)
                work_saved = true
              end

              # create and save file
              file_attributes = { title: [filename],
                                  date_created: work_attributes['date_issued'],
                                  related_url: [source_url] }
              file_set = FileSet.create(file_attributes)
              actor = Hyrax::Actors::FileSetActor.new(file_set, User.where(uid: @config['depositor_onyen']).first)
              actor.create_metadata(file_attributes)
              file = File.open(pdf_location)
              actor.create_content(file)
              actor.attach_to_work(work)
              file.close

              file_set.visibility = file_visibility
              if file_visibility == vis_public && !embargo_release_date.nil?
                file_set.embargo_release_date = embargo_release_date
                file_set.visibility_during_embargo = vis_private
                file_set.visibility_after_embargo = vis_public
              end
              file_set.save!

              attached_file_count += 1

              puts "[#{Time.now}] #{item_data['onescience_id']},#{work.id} saved file #{file_index+1} of #{file_count}"
            else
              puts "[#{Time.now}] #{item_data['onescience_id']} error: could not find file #{file_id}"
            end
          end
          if attached_file_count == 0
            puts "[#{Time.now}] #{item_data['onescience_id']} work has no files and will not be saved"
            @skipped_objects.add_entry(item_data['onescience_id'])
          else
            @object_progress.add_entry(item_data['onescience_id'])
          end
        else
          puts "[#{Time.now}] #{item_data['onescience_id']} work has no files and will not be saved"
          @skipped_objects.add_entry(item_data['onescience_id'])
        end
      end

      puts "[#{Time.now}] Completed ingest of onescience articles in #{@config['metadata_file']}"
    end

    def load_data
      # load scopus xml data
      load_scopus_data

      # get list of pdf files
      @pdf_files = Dir.glob("#{@config['pdf_dir']}/**/*.pdf")
      puts "[#{Time.now}] found #{@pdf_files.count} files"

      # read from embargo spreadsheet
      @embargo_mapping = CSV.read(File.join(@config['metadata_dir'], @config['embargo_file']), headers: true)
      puts "[#{Time.now}] loaded embargo mappings"

      # read from xlsx in projects folder
      workbook = Roo::Spreadsheet.open(File.join(@config['metadata_dir'], @config['metadata_file']))
      sheets = workbook.sheets
      @data = []
      sheets.each do |sheet|
        if sheet.match('1foldr_UNCCH_01_Part')
          data_hash = workbook.sheet(sheet).parse(headers: true)
          data_hash.delete_if{|hash| hash['onescience_id'].blank? }
          # first hash is of headers
          data_hash.delete_at(0)
          @data << data_hash
        end
      end
      @data.flatten!
    end

    def create_deposit_record
      if File.exist?(@config['deposit_record_id_log']) && !(File.open(@config['deposit_record_id_log']) {|f| f.readline}).blank?
        @deposit_record_id = (File.open(@config['deposit_record_id_log']) {|f| f.readline}).strip
        puts "[#{Time.now}] loaded deposit record id for batch"
      else
        deposit_record = DepositRecord.new({ title: @config['deposit_title'],
                                             deposit_method: @config['deposit_method'],
                                             deposit_package_type: @config['deposit_type'],
                                             deposit_package_subtype: @config['deposit_subtype'],
                                             deposited_by: @depositor_onyen })
        # attach metadata file to deposit record
        original_metadata = FedoraOnlyFile.new({'title' => @config['metadata_file'],
                                                'deposit_record' => deposit_record})
        original_metadata.file.content = File.open(File.join(@config['metadata_dir'], @config['metadata_file']))
        original_metadata.save!
        deposit_record[:manifest] = [original_metadata.uri]
        deposit_record.save!
        @deposit_record_id = deposit_record.uri
        File.open(@config['deposit_record_id_log'], 'a+') do |f|
          f.puts @deposit_record_id
        end
      end
    end

    def parse_onescience_metadata(onescience_data)
      work_attributes = {}
      identifiers = []
      identifiers << "Onescience id: #{onescience_data['onescience_id']}"
      identifiers << "Publisher DOI: https://doi.org/#{onescience_data['DOI']}" if !onescience_data['DOI'].blank?
      identifiers << "PMID: #{onescience_data['PMID']}" if !onescience_data['PMID'].blank?
      identifiers << "PMCID: #{onescience_data['PMCID']}" if !onescience_data['PMCID'].blank?
      work_attributes['identifier'] = identifiers.compact
      work_attributes['date_issued'] = (Date.try(:edtf, onescience_data['Year']) || onescience_data['Year']).to_s
      work_attributes['title'] = onescience_data['Title']
      work_attributes['label'] = work_attributes['title']
      work_attributes['journal_title'] = onescience_data['Journal Title']
      if !@scopus_hash[onescience_data['DOI'].downcase].blank?
        volume = @scopus_hash[onescience_data['DOI'].downcase]['volume']
        issue = @scopus_hash[onescience_data['DOI'].downcase]['issue']
        scopus_page_start = @scopus_hash[onescience_data['DOI'].downcase]['page_start']
        scopus_page_end = @scopus_hash[onescience_data['DOI'].downcase]['page_end']
      else
        volume, issue, scopus_page_start, scopus_page_end = nil
      end
      work_attributes['journal_volume'] = volume.blank? ? onescience_data['Volume'].to_s : volume
      journal_issue = issue.blank? ? onescience_data['Issue'].to_s : issue
      if journal_issue != 'C'
        work_attributes['journal_issue'] = journal_issue
      else
        puts "[#{Time.now}] #{onescience_data['onescience_id']} error: journal issue value is 'C'"
      end
      page_start = scopus_page_start.blank? ? onescience_data['First Page'].to_s : scopus_page_start
      if !page_start.blank? && page_start.to_i > 1000
        puts "[#{Time.now}] #{onescience_data['onescience_id']} error: journal start page is #{page_start}"
      else
        work_attributes['page_start'] = page_start
      end
      page_end = scopus_page_end.blank? ? onescience_data['Last Page'].to_s : scopus_page_end
      if !page_end.blank? && page_end.to_i > 1000
        puts "[#{Time.now}] #{onescience_data['onescience_id']} error: journal end page is #{page_end}"
      else
        work_attributes['page_end'] = page_end
      end
      work_attributes['issn'] = onescience_data['ISSNs'].split('||') if !onescience_data['ISSNs'].blank?
      work_attributes['abstract'] = onescience_data['Abstract']
      work_attributes['keyword'] = onescience_data['Keywords'].split('||') if !onescience_data['Keywords'].blank?
      work_attributes['creators_attributes'] = get_people(onescience_data)
      work_attributes['resource_type'] = 'Article'
      work_attributes['language'] = 'http://id.loc.gov/vocabulary/iso639-2/eng'
      work_attributes['language_label'] = 'English'
      work_attributes['dcmi_type'] = 'http://purl.org/dc/dcmitype/Text'
      work_attributes['admin_set_id'] = @admin_set_id
      work_attributes['rights_statement'] = 'http://rightsstatements.org/vocab/InC/1.0/'
      work_attributes['rights_statement_label'] = 'In Copyright'
      work_attributes['deposit_record'] = @deposit_record_id
      files = onescience_data.select { |k,v| k['Files'] && !v.blank? }

      work_attributes.reject!{|k,v| v.blank?}

      [work_attributes, files]
    end

    def get_people(onescience_data)
      people = {}
      doi = onescience_data['DOI']
      if !doi.blank? && !@scopus_hash[doi.downcase].blank? && !@scopus_hash[doi.downcase]['authors'].blank?
        people = @scopus_hash[doi.downcase]['authors']
      else
        puts "[#{Time.now}] #{onescience_data['onescience_id']} error: no scopus author information available"
        # check all author-related columns in 1science spreadsheets with data
        (1..32).each do |index|
          break if onescience_data['lastname_author'+index.to_s].blank? || onescience_data['firstname_author'+index.to_s].blank?
          name = "#{onescience_data['lastname_author'+index.to_s]}, #{onescience_data['firstname_author'+index.to_s]}"
          affiliations = onescience_data['affiliation_author'+index.to_s]
          people[index-1] = { 'name' => name,
                              'orcid' => onescience_data['ORCID_author'+index.to_s],
                              'affiliation' => (affiliations.split('||') if !affiliations.blank?),
                              'index' => index}
        end
      end

      people
    end

    # make hash of data with doi as key
    # authors, author order, author affiliations
    def load_scopus_data
      @scopus_hash = Hash.new

      responses=[]
      Array.wrap(@config['scopus_xml_file']).each do|xml_file|
        scopus_file = File.read(File.join(@config['metadata_dir'] , xml_file))
        query_responses = scopus_file.split(/\<object\>/)
        query_responses.delete_at(0)
        responses = responses + query_responses
      end
      mapped_affiliations = CSV.read(File.join(@config['metadata_dir'],@config['mapped_scopus_affiliations']),headers:true)
      puts"[#{Time.now}] loaded scopus files"

      # add headers to file documenting people info for each record
      File.open(@config['multiple_unc_affiliations'], 'w') do |f|
        f.puts "doi\tmultiple?\tauthor_id\tname\torcid\taffiliation\tother affiliation\tindex"
      end

      responses.each do |response|
        # parse xml
        scopus_xml = Nokogiri::XML(response)

        # find author-affiliation groupings
        authors = scopus_xml.xpath('abstracts-retrieval-response/authors//author[not(@*)]')
        affiliation = scopus_xml.xpath('abstracts-retrieval-response/affiliation')
        record_doi = scopus_xml.xpath('abstracts-retrieval-response/coredata/doi').text.downcase
        volume = scopus_xml.xpath('abstracts-retrieval-response/coredata/volume').text.downcase
        issue = scopus_xml.xpath('abstracts-retrieval-response/coredata/issueIdentifier').text.downcase
        page_start = scopus_xml.xpath('abstracts-retrieval-response/coredata/startingPage').text.downcase
        page_end = scopus_xml.xpath('abstracts-retrieval-response/coredata/endingPage').text.downcase

        # make hash of affiliation(s) since author info only has id now
        affiliation_hash = Hash.new()
        affiliations = affiliation.xpath('affiliation')
        if affiliations.blank?
          affiliation_id = affiliation.xpath('id').text
          affiliation_name = affiliation.xpath('affilname').text
          affiliation_hash[affiliation_id] = affiliation_name
        else
          affiliations.each do |affiliation|
            affiliation_id = affiliation.xpath('id').text
            affiliation_name = affiliation.xpath('affilname').text
            affiliation_hash[affiliation_id] = affiliation_name
          end
        end

        record_affiliation_hash = Hash.new { |h, k| h[k] = [] }
        begin
          # create array for each person for current record
          authors.each do |author|
            # get affiliation info
            affiliation_ids = author.xpath('affiliation/affiliation[not(@*)]')
            affiliation_ids = author.xpath('affiliation[not(@*)]') if affiliation_ids.blank?
            author_id = author.xpath('auid').text
            orcid = author.xpath('orcid').text
            if !affiliation_ids.blank?
              affiliation_ids.each do |affiliation|
                affiliation_id = affiliation.xpath('id').text
                record_affiliation_hash[author_id] << {'afid' => affiliation_id,
                                                       'organization' => affiliation_hash[affiliation_id],
                                                       'orcid' => orcid}
              end
            else
              record_affiliation_hash[author_id] << {'orcid' => orcid}
            end
          end

          # create hash of people for record
          record_authors = Hash.new
          first_author = scopus_xml.xpath('//coredata/creator/author/author-url').text
          scopus_xml.xpath('//abstracts-retrieval-response/authors//author[not(@*)]').each_with_index do |author, index|
            # get person info
            surname = author.xpath('surname').text
            if !surname.blank?
              given_name = author.xpath('preferred-name/given-name').text
              author_id = author.xpath('auid').text
              affiliations = record_affiliation_hash[author_id]

              # split unc from external affiliations
              unc_organizations = []
              other_organizations = []
              orcid = nil
              affiliations.each do |affiliation|
                orcid = affiliation['orcid']

                # find all unc affiliations by scopus afid
                if !affiliation['organization'].blank?
                  if UNC_SCOPUS_AFIDS.include?(affiliation['afid'])
                    mapped_affiliation = mapped_affiliations.find{|mapped_affil| (mapped_affil['affiliation_id'] == affiliation['afid'] && mapped_affil['department_id'].blank?)}
                    # if affiliation/department combination matches any unc affiliation, then store it as a unc affiliation
                    if mapped_affiliation
                      unc_organizations << mapped_affiliation['mapped_affiliation']
                    else # if the afid matches a known unc afid, but was not mapped, log it and still store it as a unc affiliation
                      puts "non-mapped affiliation: #{affiliation}"
                      unc_organizations << affiliation['organization']
                    end
                  else
                    if affiliation['organization'].match('UNC')
                      puts "affiliation which contains 'UNC' but is not in the list of UNC afids: #{author_id}, #{affiliations}"
                    end
                    other_organizations << affiliation['organization']
                  end
                end
              end

              # log record-person-affiliation data for restoring multiple affiliations later
              multiple = 'false'
              if unc_organizations.count > 1
                multiple = 'true'
              end
              File.open(@config['multiple_unc_affiliations'], 'a+')  do |f|
                f.puts "#{record_doi}\t#{multiple}\t#{author_id}\t#{surname}, #{given_name}\t#{orcid}\t#{unc_organizations.join('||')}\t#{other_organizations.join('||')}\t#{index+1}"
              end

              other_affiliation = (other_organizations + unc_organizations.drop(1)).reject{|i| i.blank?}
              other_affiliation = nil if other_affiliation.blank?
              # create hash for person with index value
              record_authors[index] = {'name' => surname+', '+given_name,
                                       'orcid' => orcid,
                                       'affiliation' => unc_organizations.first,
                                       'other_affiliation' => other_affiliation,
                                       'index' => index+1}.reject{|i| i.blank?}

              # verify that first author is first in list
              if index == 0
                author_url = author.xpath('author-url').text
                if author_url != first_author && !author_url.blank? && !first_author.blank?
                  puts 'authors not in correct order '+first_author
                end
              end
            end
          end

          @scopus_hash[record_doi] = {'authors' => record_authors, 'volume' => volume, 'issue' => issue,
                                      'page_start' => page_start, 'page_end' => page_end}
        rescue => e
          puts e.message, e.backtrace
          puts author_groups
        end
      end

      puts "[#{Time.now}] parsed scopus files"
    end
  end
end
