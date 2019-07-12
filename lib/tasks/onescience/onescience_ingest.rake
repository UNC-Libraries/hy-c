namespace :onescience do
  require 'roo'

  desc 'batch migrate 1science articles from spreadsheet'
  task :ingest, [:configuration_file] => :environment do |t, args|
    # config file with worktype, adminset, depositor, walnut mount location
    config = YAML.load_file(args[:configuration_file])

    @admin_set_id = ::AdminSet.where(title: config['admin_set']).first.id

    # get list of pdf files
    pdf_files = Dir.glob("#{config['pdf_dir']}/**/*.pdf")

    # read from xlsx in projects folder
    spreadsheet = Roo::Spreadsheet.open(config['metadata_dir']+'/'+config['metadata_file'])
    sheets = spreadsheet.sheets
    puts sheets.count
    # iterate through sheets if more than 1
    data = spreadsheet.sheet(0).parse(headers: true)
    # first hash is of headers
    data.delete_at(0)

    # extract needed metadata and create articles
    data.each_with_index do |item_data, index|
      # skip if article already exists in the cdr
      if item_data['Is bibliographic data in IR'] != 'No'
        puts "Article is already in the CDR: #{item_data['onescience_id']}"
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
      work.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC

      work.save!
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
        sources = []
        files.each_with_index do |(k,v),file_index|
          source_url = item_data[k.chomp('_Files')]
          if sources.include?(v)
            puts "skipping duplicate file: #{v}"
            next
          else
            sources << v
          end

          visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE

          if k.include? 'PubMedCentral-Link'
            filename = "PubMedCentral-#{source_url.split('articles/').last.split('/').first}.pdf"
            # set as primary, public file if publisher version is allowed to be shared
            if item_data['PDF'] == 'ü'
              visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
            end
          elsif k.include? 'EuropePMC-Link'
            filename = "EuropePMC-#{source_url.split('accid=').last.split('&').first}.pdf"
            # set as primary, public file if publisher version is allowed to be shared and pubmed central is not available
            if item_data['PDF'] == 'ü' && !item_data.key?('PubMedCentral-Link')
              visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
            end
          else
            if source_url.match(/.*\/[a-zA-Z0-9._-]*\.pdf$/)
              filename = source_url.split('/').last
            else
              puts "Nonstandard source url: #{source_url}"
              filename = "#{v}.pdf"
            end
            # set as primary, public file if publisher version is allowed to be shared and no pubmed files are available
            if item_data['PDF'] == 'ü' && file_index == 0
              visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
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

            file_set.visibility = visibility
            file_set.save
          end
        end
      end
    end

    # metadata file?
    # deposit record?
    # cleanup?
  end

  def parse_onescience_metadata(onescience_data)
    work_attributes = {}
    identifiers = []
    identifiers << onescience_data['onescience_id']
    identifiers << onescience_data['DOI']
    identifiers << onescience_data['PMID']
    identifiers << onescience_data['PMCID']
    work_attributes['identifier'] = identifiers.compact
    work_attributes['date_issued'] = (Date.try(:edtf, onescience_data['Year']) || onescience_data['Year']).to_s
    work_attributes['title'] = onescience_data['Title']
    work_attributes['journal_title'] = onescience_data['Journal Title']
    work_attributes['journal_volume'] = onescience_data['Volume']
    work_attributes['journal_issue'] = onescience_data['Issue']
    work_attributes['page_start'] = onescience_data['First Page']
    work_attributes['page_end'] = onescience_data['Last Page']
    work_attributes['issn'] = onescience_data['ISSNs'].split('||') if !onescience_data['ISSNs'].blank?
    work_attributes['abstract'] = onescience_data['Abstract']
    work_attributes['keyword'] = onescience_data['Keywords'].split('||') if !onescience_data['Keywords'].blank?
    work_attributes['creators_attributes'] = get_people(onescience_data)
    work_attributes['resource_type'] = 'Article'
    work_attributes['language'] = 'http://id.loc.gov/vocabulary/iso639-2/eng'
    work_attributes['dcmi_type'] = 'http://purl.org/dc/dcmitype/Text'
    work_attributes['admin_set_id'] = @admin_set_id
    # edition?
    # rights statement?
    files = onescience_data.select { |k,v| k['Files'] && !v.blank? }

    [work_attributes, files]
  end

  def get_people(metadata)
    people = {}
    (1..32).each do |index|
      break if metadata['lastname_author'+index.to_s].blank? && metadata['firstname_author'+index.to_s].blank?
      name = "#{metadata['lastname_author'+index.to_s]}, #{metadata['firstname_author'+index.to_s]}"
      people[index-1] = { 'name' => name,
                          'orcid' => metadata['ORCID_author'+index.to_s],
                          'other_affiliation' => metadata['affiliation_author'+index.to_s]}
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
