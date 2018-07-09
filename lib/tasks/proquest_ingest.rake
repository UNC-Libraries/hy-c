namespace :proquest do
  # coding: utf-8
  require 'fileutils'
  require 'tasks/migration/migration_logging'
  require 'htmlentities'
  require 'tasks/migration/migration_constants'
  require 'zip'

  # set fedora access URL. replace with fedora username and password
  # test environment will not have access to ERA's fedora

  # Must include the email address of a valid user in order to ingest files
  @depositor_email = 'admin@example.com'

  # temporary location for file download
  @temp = 'lib/tasks/ingest/tmp'
  @file_store = 'lib/tasks/migration/files'
  @temp_foxml = 'lib/tasks/tmp/tmp'
  FileUtils::mkdir_p @temp

  # report directory
  @reports = 'lib/tasks/migration/reports/'
  # Oddities report
  @oddities = @reports+ 'oddities.txt'
  # verification error report
  @verification_error = @reports + 'verification_errors.txt'
  # item migration list
  @item_list = @reports + 'item_list.txt'
  # collection list
  @collection_list = @reports + 'collection_list.txt'
  FileUtils::mkdir_p @reports
  # successful_path
  @completed_dir = 'lib/tasks/migration/completed'
  FileUtils::mkdir_p @completed_dir


  desc 'batch migrate generic files from FOXML file'
  task :ingest, [:directory, :admin_set] => :environment do |t, args|

    # Should deposit works into an admin set
    # Update title parameter to reflect correct admin set
    @admin_set_id = ::AdminSet.where(title: args[:admin_set]).first.id

    metadata_dir = args[:directory]
    migrate_proquest_packages(metadata_dir)
  end

  def migrate_proquest_packages(metadata_dir)
    proquest_packages = Dir.glob("#{metadata_dir}/*.zip")
    proquest_packages.each do |package|
      puts "Unpacking #{package}"
      @file_last_modified = ''
      extract_proquest_files(package)
      metadata_files = Dir.glob("#{@temp}/**/*")

      metadata_files.sort.each do |file|
        if File.file?(file)
          if file.match('.xml')
            metadata_fields = proquest_metadata(file, metadata_dir)

            puts "Number of files: #{metadata_fields[:files].count.to_s}"

            resource = proquest_record(metadata_fields[:resource])
            resource.save!

            ingest_proquest_files(resource: resource,
                         files: metadata_fields[:files],
                         metadata: metadata_fields[:resource],
                         zip_dir_files: metadata_files)
          end
        end
      end
      FileUtils.rm_rf(@temp)
    end
  end

  def extract_proquest_files(file)
    fname = file.split('.zip')[0].split('/')[-1]
    FileUtils::mkdir_p @temp+'/'+fname
    Zip::File.open(file) do |zip_file|
      zip_file.each do |f|
        if f.name.match(/DATA.xml/)
          @file_last_modified = Date.strptime(zip_file.get_entry(f).as_json['time'].split('T')[0],"%Y-%m-%d")
        end
        fpath = File.join(@temp+'/'+fname, f.name)
        puts fpath
        zip_file.extract(f, fpath) unless File.exist?(fpath)
      end
    end
  end

  def ingest_proquest_files(resource: nil, files: [], metadata: nil, zip_dir_files: nil)
    ordered_members = []

    files.each do |f|
      file_path = zip_dir_files.find { |e| e.match(f) }
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
    fileset_metadata = resource.slice('visibility', 'embargo_release_date', 'visibility_during_embargo',
                                      'visibility_after_embargo')
    if resource['embargo_release_date'].blank?
      fileset_metadata.except!('embargo_release_date', 'visibility_during_embargo', 'visibility_after_embargo')
    end
    file_set = FileSet.create(fileset_metadata)
    actor = Hyrax::Actors::FileSetActor.new(file_set, User.find_by_email(@depositor_email))
    actor.create_metadata(resource)
    file = File.open(f)
    actor.create_content(file)
    actor.attach_to_work(parent)
    file.close

    file_set
  end

  def proquest_metadata(metadata_file, metadata_dir)
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

    creators = metadata.xpath('//DISS_submission/DISS_authorship/DISS_author/DISS_name').map do |creator|
      if creator.xpath('DISS_affiliation').text.eql? 'University of North Carolina at Chapel Hill'
        format_name(creator)
      end
    end

    degree_granting_institution = metadata.xpath('//DISS_description/DISS_institution/DISS_inst_name').text

    keywords = metadata.xpath('//DISS_description/DISS_categorization/DISS_keyword').text.split(', ')
    keywords << metadata.xpath('//DISS_description/DISS_categorization/DISS_category/DISS_cat_desc').text

    abstract = metadata.xpath('//DISS_content/DISS_abstract').text

    advisor = metadata.xpath('//DISS_description/DISS_advisor/DISS_name').map do |advisor|
      advisor.xpath('DISS_surname').text+', '+advisor.xpath('DISS_fname').text+' '+advisor.xpath('DISS_middle').text
    end
    committee_members = metadata.xpath('//DISS_description/DISS_cmte_member/DISS_name').map do |advisor|
      format_name(advisor)
    end
    advisor += committee_members

    degree = metadata.xpath('//DISS_description/DISS_degree').text

    genre = ''
    resource_type = ''
    normalized_degree = degree.downcase.gsub('.', '')
    if normalized_degree.in? ['edd', 'phd', 'drph']
      genre = 'Dissertation'
      resource_type = 'Dissertation'
    else
      genre = 'Thesis'
      resource_type = 'Masters Thesis'
    end

    academic_concentration = metadata.xpath('//DISS_description/DISS_institution/DISS_inst_contact').text

    department = metadata.xpath('//DISS_description/DISS_institution/DISS_inst_contact').text.strip

    date_issued = metadata.xpath('//DISS_description/DISS_dates/DISS_accept_date').text
    date_issued = Date.strptime(date_issued,"%m/%d/%Y").strftime('%Y-%m-%d')

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
      language = 'English'
    end

    file_full << metadata.xpath('//DISS_content/DISS_binary').text
    file_full += metadata.xpath('//DISS_content/DISS_attachment').map do |file_name|
      file_name.xpath('DISS_file_name').text
    end

    work_attributes = {
        'title'=>[title],
        'creator'=>creators,
        'degree_granting_institution'=> degree_granting_institution,
        'keyword'=>keywords,
        'abstract'=>abstract.gsub(/\n/, "").strip,
        'advisor'=>advisor,
        'degree'=>degree,
        'academic_concentration'=>academic_concentration,
        'graduation_year'=>graduation_year,
        'date_issued'=>(Date.try(:edtf, date_issued) || date_issued).to_s,
        'genre'=>genre,
        'resource_type'=>resource_type,
        'language'=>language,
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
    resource.creator = work_attributes['creator']
    resource.depositor = @depositor_email

    resource.label = work_attributes['title'][0]
    resource.title = work_attributes['title']
    resource.keyword =  work_attributes['keyword']
    resource.degree_granting_institution = work_attributes['degree_granting_institution']
    resource.abstract = [work_attributes['abstract']]
    resource.advisor = work_attributes['advisor']
    resource.degree = work_attributes['degree']
    resource.academic_concentration = [work_attributes['academic_concentration']]
    resource.graduation_year = work_attributes['graduation_year']
    resource.language = [work_attributes['language']]
    resource.date_issued = work_attributes['date_issued']
    resource.genre = [work_attributes['genre']]
    resource.resource_type = [work_attributes['resource_type']]
    resource.date_modified = DateTime.now()
    resource.date_uploaded = DateTime.now()
    resource.rights_statement = ['http://rightsstatements.org/vocab/InC-EDU/1.0/']
    resource.admin_set_id = work_attributes['admin_set_id']
    resource.visibility = work_attributes['visibility']
    unless work_attributes['embargo_release_date'].blank?
    resource.embargo_release_date = work_attributes['embargo_release_date']
    resource.visibility_during_embargo = work_attributes['visibility_during_embargo']
    resource.visibility_after_embargo = work_attributes['visibility_after_embargo']
    end

    resource
  end

  def format_name(person)
    (person.xpath('DISS_surname').text+', '+person.xpath('DISS_fname').text+' '+person.xpath('DISS_middle').text).split.join(' ')
  end
end