namespace :proquest do
  # coding: utf-8
  require 'fileutils'
  require 'tasks/migration/migration_logging'
  require 'htmlentities'
  require 'tasks/migration/migration_constants'
  require 'zip'

  desc 'batch migrate generic files from FOXML file'
  task :ingest, [:configuration_file] => :environment do |t, args|

    config = YAML.load_file(args[:configuration_file])
    
    # Create temp directory for unzipped contents
    @temp = config['unzip_dir']
    FileUtils::mkdir_p @temp

    # Should deposit works into an admin set
    # Update title parameter to reflect correct admin set
    @admin_set_id = ::AdminSet.where(title: config['admin_set']).first.id
    @depositor_onyen = config['depositor_onyen']

    # deposit record info
    @deposit_record_hash = { title: config['deposit_title'],
                             deposit_method: config['deposit_method'],
                             deposit_package_type: config['deposit_type'],
                             deposit_package_subtype: config['deposit_subtype'],
                             deposited_by: @depositor_onyen }

    migrate_proquest_packages(config['package_dir'])
  end

  def migrate_proquest_packages(metadata_dir)
    proquest_packages = Dir.glob("#{metadata_dir}/*.zip")
    proquest_packages.each do |package|
      puts "Unpacking #{package}"
      @file_last_modified = ''
      unzipped_package_dir = extract_proquest_files(package)

      # get all files in unzipped directory (should be 1 pdf and 1 xml)
      metadata_file = Dir.glob("#{unzipped_package_dir}/*_DATA.xml")
      if metadata_file.count == 1
        metadata_file = metadata_file.first.to_s
      else
        puts "#{unzipped_package_dir} has more than 1 xml file"
        next
      end
      pdf_file = Dir.glob("#{unzipped_package_dir}/*.pdf")
      if pdf_file.count == 1
        pdf_file = pdf_file.first.to_s
      else
        puts "#{unzipped_package_dir} has more than 1 pdf file"
        next
      end

      if File.file?(metadata_file)
        # only use xml file for metadata extraction
        metadata_fields = proquest_metadata(metadata_file)

        puts "Number of files: #{metadata_fields[:files].count.to_s}"

        # create deposit record
        deposit_record = DepositRecord.new(@deposit_record_hash)
        deposit_record[:manifest] = nil
        deposit_record[:premis] = nil
        deposit_record.save!

        # create disseration record
        resource = proquest_record(metadata_fields[:resource])
        resource[:deposit_record] = deposit_record.id
        resource.save!

        # get group permissions info to use for setting work and fileset permissions
        group_permissions = get_permissions_attributes
        resource.update permissions_attributes: group_permissions

        # Attach pdf and metadata files
        ingest_proquest_files(resource: resource,
                     files: metadata_fields[:files],
                     metadata: metadata_fields[:resource],
                     zip_dir_files: [metadata_file, pdf_file])

        # Attach metadata file
        fileset_attrs = { 'title' => [File.basename(metadata_file)] }
        fileset = ingest_proquest_file(parent: resource, resource: fileset_attrs, f: metadata_file)

        # Force visibility to private since it seems to be saving as public
        fileset.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
        fileset.permissions_attributes = group_permissions
        fileset.save

        resource.ordered_members << fileset
      end
    end
  end

  def extract_proquest_files(file)
    fname = file.split('.zip')[0].split('/')[-1]
    dirname = @temp+'/'+fname
    FileUtils::mkdir_p dirname
    Zip::File.open(file) do |zip_file|
      zip_file.each do |f|
        if f.name.match(/DATA.xml/)
          @file_last_modified = Date.strptime(zip_file.get_entry(f).as_json['time'].split('T')[0],"%Y-%m-%d")
        end
        fpath = File.join(dirname, f.name)
        puts fpath
        zip_file.extract(f, fpath) unless File.exist?(fpath)
      end
    end
    dirname
  end

  def ingest_proquest_files(resource: nil, files: [], metadata: nil, zip_dir_files: nil)
    ordered_members = []

    files.each do |f|
      file_path = zip_dir_files.find { |e| e.match(f.to_s) }
      puts "trying...#{f.to_s}"
      if !file_path.nil? && File.file?(file_path)
        file_set = ingest_proquest_file(parent: resource, resource: metadata, f: file_path)
        ordered_members << file_set if file_set
      end
    end

    resource.ordered_members = ordered_members
  end

  def ingest_proquest_file(parent: nil, resource: nil, f: nil)
    puts "ingesting... #{f.to_s}"
    fileset_metadata = file_record(resource)

    if fileset_metadata['embargo_release_date'].blank?
      fileset_metadata.except!('embargo_release_date', 'visibility_during_embargo', 'visibility_after_embargo')
    end
    file_set = FileSet.create(fileset_metadata)
    actor = Hyrax::Actors::FileSetActor.new(file_set, User.where(uid: @depositor_onyen).first)
    actor.create_metadata(fileset_metadata)
    file = File.open(f)
    actor.create_content(file)
    actor.attach_to_work(parent)
    file.close

    file_set
  end

  def proquest_metadata(metadata_file)
    file = File.open(metadata_file)
    metadata = Nokogiri::XML(file)
    file.close

    file_full = Array.new(0)
    representative = ''
    visibility_during_embargo = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
    visibility_after_embargo = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
    embargo_release_date = ''
    visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC

    embargo_code = metadata.xpath('//DISS_submission/@embargo_code').text

    unless embargo_code.blank?
      current_date = DateTime.now
      comp_date_string = metadata.xpath('//DISS_description/DISS_dates/DISS_comp_date').text
      comp_date = DateTime.new(comp_date_string.to_i, 12, 31)
      embargo_release_date = current_date < comp_date ? current_date : comp_date

      if embargo_code == '2'
        embargo_release_date += 1.year
      elsif ['3', '4'].include? embargo_release_date
        embargo_release_date += 2.years
      else
        embargo_release_date = ''
      end

      if !embargo_release_date.blank? && embargo_release_date != current_date && embargo_release_date < current_date
        embargo_release_date = ''
      end

      unless embargo_release_date.blank?
        visibility = visibility_during_embargo
      end
    end

    title = metadata.xpath('//DISS_description/DISS_title').text

    creators = metadata.xpath('//DISS_submission/DISS_authorship/DISS_author[@type="primary"]/DISS_name').map do |creator|
      format_name(creator)
    end

    degree_granting_institution = metadata.xpath('//DISS_description/DISS_institution/DISS_inst_name').text

    keywords = metadata.xpath('//DISS_description/DISS_categorization/DISS_keyword').text.split(', ')
    keywords << metadata.xpath('//DISS_description/DISS_categorization/DISS_category/DISS_cat_desc').map(&:text)

    abstract = metadata.xpath('//DISS_content/DISS_abstract').text

    advisor = metadata.xpath('//DISS_description/DISS_advisor/DISS_name').map do |advisor|
      advisor.xpath('DISS_surname').text+', '+advisor.xpath('DISS_fname').text+' '+advisor.xpath('DISS_middle').text
    end
    committee_members = metadata.xpath('//DISS_description/DISS_cmte_member/DISS_name').map do |advisor|
      format_name(advisor)
    end
    advisor += committee_members

    degree = metadata.xpath('//DISS_description/DISS_degree').text

    dcmi_type = ''
    resource_type = ''
    normalized_degree = degree.downcase.gsub('.', '')
    if normalized_degree.in? ['edd', 'phd', 'drph']
      dcmi_type = 'Dissertation'
      resource_type = 'Dissertation'
    else
      dcmi_type = 'Thesis'
      resource_type = 'Masters Thesis'
    end

    department = metadata.xpath('//DISS_description/DISS_institution/DISS_inst_contact').text.strip
    affiliation = ProquestDepartmentMappingsService.standard_department_name(department)

    date_issued = metadata.xpath('//DISS_description/DISS_dates/DISS_comp_date').text
    date_issued = Date.strptime(date_issued,"%Y")

    graduation_semester = ''
    if @file_last_modified.month >= 2 && @file_last_modified.month <= 6
      graduation_semester = 'Spring'
    elsif @file_last_modified.month >= 7 && @file_last_modified.month <= 9
      graduation_semester = 'Summer'
    else
      graduation_semester = 'Winter'
    end
    graduation_year = graduation_semester+' '+@file_last_modified.year.to_s

    language = metadata.xpath('//DISS_description/DISS_categorization/DISS_language').text
    if language == 'en'
      language = get_language_uri('eng')
      language_label = LanguagesService.label(language) if !language.blank?
    end

    file_full << metadata.xpath('//DISS_content/DISS_binary').text
    file_full += metadata.xpath('//DISS_content/DISS_attachment').map do |file_name|
      file_name.xpath('DISS_file_name').text
    end

    work_attributes = {
        'title'=>[title],
        'creators_attributes'=>build_person_hash(creators, affiliation),
        'date_issued'=>(Date.try(:edtf, date_issued) || date_issued).to_s,
        'abstract'=>abstract.gsub(/\n/, "").strip,
        'advisors_attributes'=>build_person_hash(advisor, nil),
        'dcmi_type'=>dcmi_type,
        'degree'=>degree,
        'degree_granting_institution'=> degree_granting_institution,
        'graduation_year'=>graduation_year,
        'language'=>language,
        'language_label'=>language_label,
        'keyword'=>keywords.flatten,
        'resource_type'=>resource_type,
        'visibility'=>visibility,
        'embargo_release_date'=>(Date.try(:edtf, embargo_release_date)).to_s,
        'visibility_during_embargo'=>visibility_during_embargo,
        'visibility_after_embargo'=>visibility_after_embargo,
        'admin_set_id'=>@admin_set_id
    }

    { resource: work_attributes, files: file_full }

  end

  def proquest_record(work_attributes)
    resource = Dissertation.new
    resource.creators = work_attributes['creators_attributes'].map{ |k,v| resource.creators.build(v) }
    resource.depositor = @depositor_onyen

    resource.label = work_attributes['title'][0]
    resource.title = work_attributes['title']
    resource.keyword =  work_attributes['keyword']
    resource.degree_granting_institution = work_attributes['degree_granting_institution']
    resource.abstract = [work_attributes['abstract']]
    resource.advisors = work_attributes['advisors_attributes'].map{ |k,v| resource.advisors.build(v) }
    resource.degree = work_attributes['degree']
    resource.graduation_year = work_attributes['graduation_year']
    resource.language = [work_attributes['language']]
    resource.date_issued = work_attributes['date_issued']
    resource.dcmi_type = [work_attributes['dcmi_type']]
    resource.resource_type = [work_attributes['resource_type']]
    resource.date_modified = DateTime.now()
    resource.date_uploaded = DateTime.now()
    resource.rights_statement = 'http://rightsstatements.org/vocab/InC-EDU/1.0/'
    resource.admin_set_id = work_attributes['admin_set_id']
    resource.visibility = work_attributes['visibility']
    unless work_attributes['embargo_release_date'].blank?
    resource.embargo_release_date = work_attributes['embargo_release_date']
    resource.visibility_during_embargo = work_attributes['visibility_during_embargo']
    resource.visibility_after_embargo = work_attributes['visibility_after_embargo']
    end

    resource
  end

  def build_person_hash(people, affiliation)
    person_hash = {}
    people.each_with_index do |person, index|
      person_hash[index.to_s] = {'name' => person, 'affiliation' => affiliation}
    end

    person_hash
  end

  def format_name(person)
    name_parts = []
    name_parts << person.xpath('DISS_surname').text
    name_parts << (person.xpath('DISS_fname').text+' '+person.xpath('DISS_middle').text).strip
    name_parts << person.xpath('DISS_suffix').text
    name_parts.reject{ |name| name.blank? }.join(', ')
  end

  # Use language code to get iso639-2 uri from service
  def get_language_uri(language_code)
    LanguagesService.label("http://id.loc.gov/vocabulary/iso639-2/#{language_code.downcase}") ?
        "http://id.loc.gov/vocabulary/iso639-2/#{language_code.downcase}" : nil
  end

  # FileSets can include any metadata listed in BasicMetadata file
  def file_record(attrs)
    file_set = FileSet.new
    file_attributes = Hash.new

    # Singularize non-enumerable attributes and make sure enumerable attributes are arrays
    attrs.each do |k,v|
      if file_set.attributes.keys.member?(k.to_s)
        if !file_set.attributes[k.to_s].respond_to?(:each) && file_attributes[k].respond_to?(:each)
          file_attributes[k] = v.first
        elsif file_set.attributes[k.to_s].respond_to?(:each) && !file_attributes[k].respond_to?(:each)
          file_attributes[k] = Array(v)
        else
          file_attributes[k] = v
        end
      end
    end
    
    file_attributes[:date_created] = attrs['date_created']
    file_attributes[:visibility] = attrs['visibility']
    unless attrs['embargo_release_date'].blank?
      file_attributes[:embargo_release_date] = attrs['embargo_release_date']
      file_attributes[:visibility_during_embargo] = attrs['visibility_during_embargo']
      file_attributes[:visibility_after_embargo] = attrs['visibility_after_embargo']
    end

    file_attributes
  end


  def get_permissions_attributes
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