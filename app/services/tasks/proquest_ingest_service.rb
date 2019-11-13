module Tasks
  require 'fileutils'
  require 'tasks/migration/migration_logging'
  require 'htmlentities'
  require 'tasks/migration/migration_constants'
  require 'zip'
  require 'tasks/migration_helper'

  class ProquestIngestService
    attr_reader :temp, :admin_set_id, :depositor_onyen, :deposit_record_hash, :metadata_dir

    def initialize(args)
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

      @metadata_dir = config['package_dir']
    end

    def migrate_proquest_packages
      # sort zip files for tests
      proquest_packages = Dir.glob("#{@metadata_dir}/*.zip").sort
      count = proquest_packages.count
      proquest_packages.each_with_index do |package, index|
        puts "[#{Time. now}] Unpacking #{package} (#{index+1} of #{count})"
        @file_last_modified = ''
        unzipped_package_dir = extract_proquest_files(package)

        if unzipped_package_dir.blank?
          puts "[#{Time.now}] error extracting #{package}: skipping zip file"
          next
        end

        # get all files in unzipped directory (should be 1 pdf and 1 xml)
        metadata_file = Dir.glob("#{unzipped_package_dir}/*_DATA.xml")
        if metadata_file.count == 1
          metadata_file = metadata_file.first.to_s
        else
          puts "[#{Time.now}] error: #{unzipped_package_dir} has #{metadata_file.count} xml file(s)"
          next
        end
        pdf_file = Dir.glob("#{unzipped_package_dir}/*.pdf")
        if pdf_file.count == 1
          pdf_file = pdf_file.first.to_s
        else
          puts "[#{Time.now}] error: #{unzipped_package_dir} has more than 1 pdf file"
          next
        end

        # delete zip file after files have been extracted successfully
        if Rails.env != 'test'
          File.delete(package)
        end

        if File.file?(metadata_file)
          # only use xml file for metadata extraction
          metadata, listed_files = proquest_metadata(metadata_file)

          puts "[#{Time.now}] #{metadata_file}, Number of files: #{listed_files.count.to_s}"

          # create deposit record
          deposit_record = DepositRecord.new(@deposit_record_hash)
          deposit_record[:manifest] = nil
          deposit_record[:premis] = nil
          deposit_record.save!

          # create disseration record
          resource = MigrationHelper.check_enumeration(metadata, Dissertation.new, metadata_file)
          resource.visibility = metadata['visibility']
          unless metadata['embargo_release_date'].blank?
            resource.visibility_during_embargo = metadata['visibility_during_embargo']
            resource.visibility_after_embargo = metadata['visibility_after_embargo']
            resource.embargo_release_date = metadata['embargo_release_date']
          end
          resource[:deposit_record] = deposit_record.id

          resource.save!

          id = resource.id

          puts "[#{Time.now}][#{metadata_file}] created dissertation: #{id}"

          # get group permissions info to use for setting work and fileset permissions
          group_permissions = MigrationHelper.get_permissions_attributes(@admin_set_id)
          resource.update permissions_attributes: group_permissions

          # get list of all files in unzipped proquest package
          unzipped_file_list = Dir.glob("#{unzipped_package_dir}/**/*.*")

          ordered_members = []
          listed_files.each do |f|
            puts "[#{Time.now}][#{id}] trying...#{f.to_s}"

            file_path = unzipped_file_list.find { |e| e.match(f.to_s) }
            if file_path.blank?
              puts "[#{Time.now}][#{id}] cannot find #{f.to_s}"
              next
            end

            if File.file?(file_path)
              file_set = ingest_proquest_file(parent: resource,
                                              resource: metadata.merge({title: [f]}),
                                              f: file_path)
              ordered_members << file_set if file_set
            end
          end
          resource.ordered_members = ordered_members

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
      begin
        Zip::File.open(file) do |zip_file|
          zip_file.each do |f|
            if f.name.match(/DATA.xml/)
              @file_last_modified = Date.strptime(zip_file.get_entry(f).as_json['time'].split('T')[0],"%Y-%m-%d")
            end
            fpath = File.join(dirname, f.name)
            zip_file.extract(f, fpath) unless File.exist?(fpath)
          end
        end
        dirname
      rescue => e
        puts "[#{Time.now}] #{file}, zip file error: #{e.message}"
        nil
      end
    end

    def ingest_proquest_file(parent: nil, resource: nil, f: nil)
      puts "[#{Time.now}][#{parent.id}] ingesting... #{f.to_s}"
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
        current_date = Date.today
        comp_date_string = metadata.xpath('//DISS_description/DISS_dates/DISS_comp_date').text
        comp_date = Date.new(comp_date_string.to_i, 12, 31)
        embargo_release_date = current_date < comp_date ? current_date : comp_date

        if embargo_code == '2'
          embargo_release_date += 1.year
        elsif ['3', '4'].include? embargo_code
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

      abbreviated_degree = metadata.xpath('//DISS_description/DISS_degree').text

      dcmi_type = 'http://purl.org/dc/dcmitype/Text'
      normalized_degree = abbreviated_degree.downcase.gsub('.', '')
      degree_map = { 'ma' => 'Master of Arts',
                     'ms' => 'Master of Science',
                     'edd' => 'Doctor of Education',
                     'de' => 'Doctor of Education',
                     'phd' => 'Doctor of Philosophy',
                     'drph' => 'Doctor of Public Health',
                     'dnp' => 'Doctor of Nursing Practice'}
      if !degree_map[normalized_degree].blank?
        degree = DegreesService.label(degree_map[normalized_degree])
      else
        puts "[#{Time.now}][#{metadata_file}] unknown degree: #{abbreviated_degree}"
        degree = abbreviated_degree
      end

      resource_type = ''
      if normalized_degree.in? ['edd', 'phd', 'drph']
        resource_type = 'Dissertation'
      else
        resource_type = 'Masters Thesis'
      end

      department = metadata.xpath('//DISS_description/DISS_institution/DISS_inst_contact').text.strip
      affiliation = ProquestDepartmentMappingsService.standard_department_name(department) || department

      date_issued = metadata.xpath('//DISS_description/DISS_dates/DISS_comp_date').text
      date_issued = Date.strptime(date_issued,"%Y")

      graduation_year = @file_last_modified.year.to_s

      language = metadata.xpath('//DISS_description/DISS_categorization/DISS_language').text
      if language == 'en'
        language = MigrationHelper.get_language_uri(['eng'])
        language_label = LanguagesService.label(language) if !language.blank?
      end

      file_full << metadata.xpath('//DISS_content/DISS_binary').text
      file_full += metadata.xpath('//DISS_content/DISS_attachment').map do |file_name|
        file_name.xpath('DISS_file_name').text
      end

      work_attributes = {
          'title'=>[title],
          'label' => title,
          'depositor' => @depositor_onyen,
          'creators_attributes'=>build_person_hash(creators, affiliation),
          'date_issued'=>(Date.try(:edtf, date_issued.year) || date_issued.year).to_s,
          'abstract'=>abstract.gsub(/\n/, "").strip,
          'advisors_attributes'=>build_person_hash(advisor, nil),
          'dcmi_type'=>dcmi_type,
          'degree'=>degree,
          'degree_granting_institution'=> degree_granting_institution,
          'graduation_year'=>graduation_year,
          'language'=>language,
          'language_label'=>language_label,
          'rights_statement' => 'http://rightsstatements.org/vocab/InC-EDU/1.0/',
          'keyword'=>keywords.flatten,
          'resource_type'=>resource_type,
          'visibility'=>visibility,
          'embargo_release_date'=>(Date.try(:edtf, embargo_release_date.to_s)).to_s,
          'visibility_during_embargo'=>visibility_during_embargo,
          'visibility_after_embargo'=>visibility_after_embargo,
          'admin_set_id'=>@admin_set_id
      }

      work_attributes.reject!{|k,v| v.blank?}

      [work_attributes, file_full]
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

      file_attributes['date_created'] = attrs['date_created']
      file_attributes['visibility'] = attrs['visibility']
      unless attrs['embargo_release_date'].blank?
        file_attributes['embargo_release_date'] = attrs['embargo_release_date']
        file_attributes['visibility_during_embargo'] = attrs['visibility_during_embargo']
        file_attributes['visibility_after_embargo'] = attrs['visibility_after_embargo']
      end

      file_attributes
    end
  end
end