namespace :onescience do
  require 'roo'

  desc 'batch migrate 1science articles from spreadsheet'
  task :ingest, [:configuration_file] => :environment do |t, args|
    # config file with worktype, adminset, depositor, walnut mount location
    config = YAML.load_file(args[:configuration_file])

    # read from xlsx in projects folder
    spreadsheet = Roo::Spreadsheet.open(config['metadata_dir']+'/'+config['metadata_file'])
    sheets = spreadsheet.sheets
    puts sheets.count
    # iterate through sheets if more than 1
    data = spreadsheet.sheet(0).parse(headers: true)
    # first hash is of headers
    data.delete_at(0)

    # extract needed metadata and create articles
    data.each do |item_data|
      work_attributes = parse_onescience_metadata(item_data)

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

      work.save!
    end

    # attach pdf from folder on p-drive
    # do they all have files?
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
    # edition?
    # rights statement?

    work_attributes
  end

  def get_people(metadata)
    people = {}
    (1..32).each do |index|
      break if metadata['lastname_author'+index.to_s].blank?
      name = "#{metadata['lastname_author'+index.to_s]}, #{metadata['firstname_author'+index.to_s]}"
      people[index-1] = { 'name' => name,
                          'orcid' => metadata['ORCID_author'+index.to_s],
                          'other_affiliation' => metadata['affiliation_author'+index.to_s]}
    end

    people
  end
end
