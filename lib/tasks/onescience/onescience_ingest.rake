namespace :onescience do
  require 'roo'
  require 'tasks/migrate/services/progress_tracker'

  desc 'batch migrate 1science articles from spreadsheet'
  task :ingest, [:configuration_file] => :environment do |t, args|
    # config file with worktype, adminset, depositor, mount location
    config = YAML.load_file(args[:configuration_file])
    puts "[#{Time.now}] Start ingest of onescience articles in #{config['metadata_file']}"

    # set visibility variables
    vis_private = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
    vis_public = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC

    @admin_set_id = ::AdminSet.where(title: config['admin_set']).first.id

    # get list of pdf files
    pdf_files = Dir.glob("#{config['pdf_dir']}/**/*.pdf")

    # read from affiliation spreadsheet
    @affiliation_mapping = []
    config['affiliation_files'].each do |affiliation_file|
      workbook = Roo::Spreadsheet.open(config['metadata_dir']+'/'+affiliation_file)
      sheets = workbook.sheets
      sheets.each do |sheet|
        data_hash = workbook.sheet(sheet).parse(headers: true)
        # first hash is of headers
        data_hash.delete_at(0)
        @affiliation_mapping << data_hash
      end
    end
    @affiliation_mapping.flatten!
    puts "[#{Time.now}] loaded affiliation mappings"

    # read from embargo spreadsheet
    embargo_mapping = CSV.read(config['metadata_dir']+'/'+config['embargo_file'], headers: true)
    puts "[#{Time.now}] loaded embargo mappings"

    # read from xlsx in projects folder
    workbook = Roo::Spreadsheet.open(config['metadata_dir']+'/'+config['metadata_file'])
    sheets = workbook.sheets
    data = []
    sheets.each do |sheet|
      if sheet.match('1foldr_UNCCH_01_Part')
        data_hash = workbook.sheet(sheet).parse(headers: true)
        data_hash.delete_if{|hash| hash['onescience_id'].blank? }
        # first hash is of headers
        data_hash.delete_at(0)
        data << data_hash
      end
    end
    data.flatten!
    puts "[#{Time.now}] loaded onescience data"

    # create deposit record
    deposit_record = DepositRecord.new({ title: config['deposit_title'],
                                         deposit_method: config['deposit_method'],
                                         deposit_package_type: config['deposit_type'],
                                         deposit_package_subtype: config['deposit_subtype'],
                                         deposited_by: @depositor_onyen })
    # attach metadata file to deposit record
    original_metadata = FedoraOnlyFile.new({'title' => config['metadata_file'],
                                            'deposit_record' => deposit_record})
    original_metadata.file.content = File.open(config['metadata_dir']+'/'+config['metadata_file'])
    original_metadata.save!
    deposit_record[:manifest] = [original_metadata.uri]
    deposit_record.save!
    deposit_record_id = deposit_record.uri
    puts "[#{Time.now}] created deposit record for batch"

    # Progress tracker for objects migrated
    @object_progress = Migrate::Services::ProgressTracker.new(config['progress_log'])
    already_ingested = @object_progress.completed_set
    puts "Skipping #{already_ingested.length} previously ingested works"

    count = data.count
    # extract needed metadata and create articles
    data.each_with_index do |item_data, index|
      puts "[#{Time.now}] ingesting #{item_data['onescience_id']} (#{index+1} of #{count})"

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

      work = config['work_type'].singularize.classify.constantize.new

      # Singularize non-enumerable attributes and make sure enumerable attributes are arrays
      work_attributes.each do |k,v|
        if work.attributes.keys.member?(k.to_s) && !work.attributes[k.to_s].respond_to?(:each) && work_attributes[k].respond_to?(:each)
          work_attributes[k] = v.first
        elsif work.attributes.keys.member?(k.to_s) && work.attributes[k.to_s].respond_to?(:each) && !work_attributes[k].respond_to?(:each)
          work_attributes[k] = Array(v)
        else
          work_attributes[k] = v
        end
      end

      # Only keep attributes which apply to the given work type
      work.attributes = work_attributes.reject{|k,v| !work.attributes.keys.member?(k.to_s) unless k.to_s.ends_with? '_attributes'}
                            .merge({'deposit_record' => deposit_record_id})

      # Check for embargo data
      embargo_term = embargo_mapping.find{ |e| e['onescience_id'] = item_data['onescience_id'] }
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

      work.save!
      puts "[#{Time.now}] #{item_data['onescience_id']},#{work.id} saved new article"

      work.update permissions_attributes: get_group_permissions

      # Create sipity record
      workflow = Sipity::Workflow.joins(:permission_template)
                     .where(permission_templates: { source_id: work.admin_set_id }, active: true)
      workflow_state = Sipity::WorkflowState.where(workflow_id: workflow.first.id, name: 'deposited')
      Sipity::Entity.create!(proxy_for_global_id: work.to_global_id.to_s,
                             workflow: workflow.first,
                             workflow_state: workflow_state.first)

      # attach pdfs from folder on p-drive
      if !files.blank?
        puts "[#{Time.now}] #{item_data['onescience_id']},#{work.id} attaching files"
        sources = []
        file_count = files.count

        # Move pubmed file to beginning of hash so it will be the primary work
        if files.key?('PubMedCentral-Link_Files')
          files = {'PubMedCentral-Link_Files' => files['PubMedCentral-Link_Files']}.merge(files)
        end

        files.each_with_index do |(k,v),file_index|
          puts "[#{Time.now}] #{item_data['onescience_id']},#{work.id} attaching file #{file_index+1} of #{file_count}"
          source_url = item_data[k.chomp('_Files')]
          if sources.include?(v)
            puts "[#{Time.now}] #{item_data['onescience_id']},#{work.id} skipping duplicate file: #{v}"
            next
          else
            sources << v
          end

          file_visibility = vis_private

          # set pubmed central or first listed file as public
          if (file_index == 0 && !files.key?('PubMedCentral-Link_Files')) || (k.include? 'PubMedCentral-Link')
            file_visibility = vis_public
          end

          # parse filename
          if k.include? 'PubMedCentral-Link'
            filename = "PubMedCentral-#{source_url.split('articles/').last.split('/').first}.pdf"
          elsif k.include? 'EuropePMC-Link'
            filename = "EuropePMC-#{source_url.split('accid=').last.split('&').first}.pdf"
          else
            if source_url.match(/.*\/[a-zA-Z0-9._-]*\.pdf$/)
              filename = source_url.split('/').last
            else
              puts "[#{Time.now}] #{item_data['onescience_id']},#{work.id} nonstandard source url: #{source_url}"
              filename = "#{v}.pdf"
            end
          end

          pdf_location = pdf_files.select { |path| path.include? v }.first
          if !pdf_location.blank? # can we find the file
            file_attributes = { title: [filename],
                                date_created: work_attributes['date_issued'],
                                related_url: [source_url] }
            file_set = FileSet.create(file_attributes)
            actor = Hyrax::Actors::FileSetActor.new(file_set, User.where(uid: config['depositor_onyen']).first)
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

            puts "[#{Time.now}] #{item_data['onescience_id']},#{work.id} saved file #{file_index+1} of #{file_count}"
          end
        end
      end
      @object_progress.add_entry(item_data['onescience_id'])
    end

    puts "[#{Time.now}] Completed ingest of onescience articles in #{config['metadata_file']}"
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
    work_attributes['title'] = onescience_data['Title'].gsub(/[:\.]\z/,'')
    work_attributes['journal_title'] = onescience_data['Journal Title']
    work_attributes['journal_volume'] = onescience_data['Volume'].to_s
    work_attributes['journal_issue'] = onescience_data['Issue'].to_s
    work_attributes['page_start'] = onescience_data['First Page'].to_s
    work_attributes['page_end'] = onescience_data['Last Page'].to_s
    work_attributes['issn'] = onescience_data['ISSNs'].split('||') if !onescience_data['ISSNs'].blank?
    work_attributes['abstract'] = onescience_data['Abstract']
    work_attributes['keyword'] = onescience_data['Keywords'].split('||') if !onescience_data['Keywords'].blank?
    work_attributes['creators_attributes'] = get_people(onescience_data['onescience_id'])
    work_attributes['resource_type'] = 'Article'
    work_attributes['language'] = 'http://id.loc.gov/vocabulary/iso639-2/eng'
    work_attributes['dcmi_type'] = 'http://purl.org/dc/dcmitype/Text'
    work_attributes['admin_set_id'] = @admin_set_id
    # edition?
    # rights statement?
    files = onescience_data.select { |k,v| k['Files'] && !v.blank? }

    [work_attributes, files]
  end

  def get_people(onescience_id)
    people = {}
    affiliation_data = @affiliation_mapping.find{ |e| e['onescience_id'] == onescience_id }
    (1..32).each do |index|
      break if affiliation_data['lastname_author'+index.to_s].blank? || affiliation_data['firstname_author'+index.to_s].blank?
      name = "#{affiliation_data['lastname_author'+index.to_s]}, #{affiliation_data['firstname_author'+index.to_s]}"
      affiliations = affiliation_data['affiliation_author'+index.to_s]
      people[index-1] = { 'name' => name,
                          'orcid' => affiliation_data['ORCID_author'+index.to_s],
                          'affiliation' => (affiliations.split('||') if !affiliations.blank?)}
    end

    people
  end


  def get_group_permissions
    # find admin set and manager groups for work
    manager_groups = Hyrax::PermissionTemplateAccess.joins(:permission_template)
                         .where(access: 'manage', agent_type: 'group')
                         .where(permission_templates: {source_id: @admin_set_id})

    # update work permissions to give admin set managers edit rights
    permissions_array = []
    manager_groups.each do |manager_group|
      permissions_array << { "type" => "group", "name" => manager_group.agent_id, "access" => "edit" }
    end

    permissions_array
  end
end
