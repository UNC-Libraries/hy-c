namespace :proquest do
  # coding: utf-8
  require 'fileutils'
  require 'tasks/migration/migration_logging'
  require 'htmlentities'
  require 'tasks/migration/migration_constants'
  require 'zip'

  #set fedora access URL. replace with fedora username and password
  #test environment will not have access to ERA's fedora

  # Must include the email address of a valid user in order to ingest files
  @depositor_email = 'admin@example.com'

  #Use the ERA public interface to download original file and foxml
  @fedora_url = ENV['FEDORA_PRODUCTION_URL']

  #temporary location for file download
  @temp = 'lib/tasks/ingest/tmp'
  @file_store = 'lib/tasks/migration/files'
  @temp_foxml = 'lib/tasks/tmp/tmp'
  FileUtils::mkdir_p @temp

  #report directory
  @reports = 'lib/tasks/migration/reports/'
  #Oddities report
  @oddities = @reports+ 'oddities.txt'
  #verification error report
  @verification_error = @reports + 'verification_errors.txt'
  #item migration list
  @item_list = @reports + 'item_list.txt'
  #collection list
  @collection_list = @reports + 'collection_list.txt'
  FileUtils::mkdir_p @reports
  #successful_path
  @completed_dir = 'lib/tasks/migration/completed'
  FileUtils::mkdir_p @completed_dir

  # Sample data is currently stored in the hyrax/lib/tasks/migration/tmp directory.  Each object is stored in a
  # directory labelled with its uuid. Container objects only contain a metadata file and are stored as
  # {uuid}/uuid:{uuid}-object.xml. File objects contain a metadata file and the file to be imported which are stored in
  # the same directory as {uuid}/uuid:{uuid}.xml and {uuid}/{uuid}-DATA_FILE.*, respectively.

  desc 'batch migrate generic files from FOXML file'
  task :ingest, [:dir, :migrate_datastreams] => :environment do |t, args|
    args.with_defaults(:migrate_datastreams => "true")

    metadata_dir = args.dir
    migrate_objects(metadata_dir)
  end

  def migrate_objects(metadata_dir)
    proquest_packages = Dir.glob("#{metadata_dir}/*.zip")
    extract_files(proquest_packages)
    metadata_files = Dir.glob("#{@temp}/**/*")

    puts 'Object count: '+metadata_files.count.to_s

    metadata_files.sort.each do |file|
      if File.file?(file)
        if file.match('.xml')
          metadata_fields = metadata(file, metadata_dir)

          puts 'Number of files: '+metadata_fields[:files].count.to_s

          resource = work_record(metadata_fields[:resource])
          resource.save!

          ingest_files(resource: resource, files: metadata_fields[:files], metadata: metadata_fields[:resource], zip_dir_files: metadata_files)
        end
      end
    end
    FileUtils.rm_rf(@temp)
  end

  def extract_files(files)
    files.each do |file|
      fname = file.split('.zip')[0].split('/')[-1]
      FileUtils::mkdir_p @temp+'/'+fname
      Zip::File.open(file) do |zip_file|
        zip_file.each do |f|
          fpath = File.join(@temp+'/'+fname, f.name)
          puts fpath
          zip_file.extract(f, fpath) unless File.exist?(fpath)
        end
      end
    end
  end

  def ingest_files(resource: nil, files: [], metadata: nil, zip_dir_files: nil)
    ordered_members = []

    files.each do |f|
      file_path = zip_dir_files.find { |e| e.match(f) }
      puts 'testing... '+f.to_s
      if !file_path.nil? && File.file?(file_path)
        file_set = ingest_file(parent: resource, resource: metadata, f: file_path)
        ordered_members << file_set if file_set
      end
    end

    resource.ordered_members = ordered_members
  end

  def ingest_file(parent: nil, resource: nil, f: nil)
    puts 'ingesting... '+f.to_s
    file_set = FileSet.create(resource.slice(:title, :label, :creator, :depositor, :visibility))
    actor = Hyrax::Actors::FileSetActor.new(file_set, User.find_by_email(@depositor_email))
    actor.create_metadata(resource.slice(:visibility, :visibility_during_lease, :visibility_after_lease,
                                          :lease_expiration_date, :embargo_release_date, :visibility_during_embargo,
                                          :visibility_after_embargo))
    file = File.open(f)
    actor.create_content(file)
    actor.attach_to_work(parent)
    file.close

    file_set
  end

  def metadata(metadata_file, metadata_dir)
    file = File.open(metadata_file)
    metadata = Nokogiri::XML(file)

    file_full = Array.new(0)
    representative = ''
    visibility_during_embargo = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
    visibility_after_embargo = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
    embargo_release_date = ''
    visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC

    title = metadata.xpath('//DISS_description/DISS_title').text
    creators = metadata.xpath('//DISS_submission/DISS_authorship/DISS_author/DISS_name').map do |creator|
      if creator.xpath('DISS_affiliation').text.eql? 'University of North Carolina at Chapel Hill'
        creator.xpath('DISS_surname').text+', '+creator.xpath('DISS_fname').text+' '+creator.xpath('DISS_middle').text
      end
    end
    degree_granting_institution = metadata.xpath('//DISS_description/DISS_institution/DISS_inst_name').text
    keywords = metadata.xpath('//DISS_description/DISS_categorization/DISS_keyword').text.split(', ')
    abstract = metadata.xpath('//DISS_content/DISS_abstract/DISS_para').text
    advisor = metadata.xpath('//DISS_description/DISS_advisor/DISS_name').map do |advisor|
      advisor.xpath('DISS_surname').text+', '+advisor.xpath('DISS_fname').text+' '+advisor.xpath('DISS_middle').text
    end
    degree = metadata.xpath('//DISS_description/DISS_degree').text
    academic_department = metadata.xpath('//DISS_description/DISS_categorization/DISS_category/DISS_cat_desc').text

    file_full << metadata.xpath('//DISS_content/DISS_binary').text
    file_full += metadata.xpath('//DISS_content/DISS_attachment').map do |file_name|
      file_name.xpath('DISS_file_name').text
    end

    file.close

    work_attributes = {
        'title'=>[title+Time.now().strftime('%Y-%m-%dT%H:%M:%S.%N%Z')],
        'creator'=>creators,
        'degree_granting_institution'=> degree_granting_institution,
        'keyword'=>keywords,
        'abstract'=>abstract,
        'advisor'=>advisor,
        'degree'=>degree,
        'academic_department'=>academic_department,
        'visibility'=>visibility,
        'embargo_release_date'=>embargo_release_date,
        'visibility_during_embargo'=>visibility_during_embargo,
        'visibility_after_embargo'=>visibility_after_embargo
    }

    { resource: work_attributes, files: file_full }

  end

  def work_record(work_attributes)
    resource = Dissertation.new
    resource.creator = work_attributes['creator']
    resource.depositor = @depositor_email
    resource.save

    resource.label = work_attributes['title'][0]
    resource.title = work_attributes['title']
    resource.keyword =  work_attributes['keyword']
    resource.degree_granting_institution = work_attributes['degree_granting_institution']
    resource.abstract = [work_attributes['abstract']]
    resource.advisor = work_attributes['advisor']
    resource.degree = work_attributes['degree']
    resource.academic_department = [work_attributes['academic_department']]
    resource.date_modified = Time.now().strftime('%Y-%m-%dT%H:%M:%S.%N%Z')
    resource.rights_statement = ['http://rightsstatements.org/vocab/InC-EDU/1.0/']
    resource.visibility = work_attributes['visibility']
    unless work_attributes['embargo_release_date'].blank?
    resource.embargo_release_date = work_attributes['embargo_release_date']
    resource.visibility_during_embargo = work_attributes['visibility_during_embargo']
    resource.visibility_after_embargo = work_attributes['visibility_after_embargo']
    end

    resource
  end

end