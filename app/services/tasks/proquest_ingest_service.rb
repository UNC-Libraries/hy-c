module Tasks
  require 'fileutils'
  require 'tasks/migration/migration_logging'
  require 'htmlentities'
  require 'tasks/migration/migration_constants'
  require 'zip'
  require 'tasks/migration_helper'

  class ProquestIngestService < IngestService
    attr_reader :admin_set_id

    def initialize(args)
      super

      @admin_set_id = @admin_set.id
    end

    def ingest_source
      'ProQuest'
    end

    # URI representing the type of packaging used for the original deposit represented by this record, such as CDR METS or BagIt.
    def deposit_package_type
      'http://proquest.com'
    end

    # Subclassification of the packaging type for this deposit, such as a METS profile.
    def deposit_package_subtype
      'ProQuest'
    end

    def process_package(package_path, _index)
      @file_last_modified = ''
      unzipped_package_dir = unzip_dir(package_path)

      # extract files
      extract_files(package_path)

      if unzipped_package_dir.blank?
        logger.error("Error extracting #{package_path}: skipping zip file")
        return
      end

      metadata_file_path = metadata_file_path(dir: unzipped_package_dir)

      pdf_file_path = Dir.glob("#{unzipped_package_dir}/*.pdf")
      unless pdf_file_path.count == 1
        logger.error("Error: #{unzipped_package_dir} has more than 1 pdf file")
        return
      end

      return unless metadata_file_path

      return unless File.file?(metadata_file_path)

      # only use xml file for metadata extraction
      metadata, listed_files = proquest_metadata(metadata_file_path)

      logger.info("#{metadata_file_path}, Number of files: #{listed_files.count.to_s}")

      # create disseration record
      resource = MigrationHelper.check_enumeration(metadata, Dissertation.new, metadata_file_path)
      resource.visibility = metadata['visibility']
      unless metadata['embargo_release_date'].blank?
        resource.visibility_during_embargo = metadata['visibility_during_embargo']
        resource.visibility_after_embargo = metadata['visibility_after_embargo']
        resource.embargo_release_date = metadata['embargo_release_date']
      end
      resource[:deposit_record] = deposit_record.id
      resource.save!

      id = resource.id

      logger.info("[#{metadata_file_path}] created dissertation: #{id}")

      # get group permissions info to use for setting work and fileset permissions
      group_permissions = MigrationHelper.get_permissions_attributes(@admin_set_id)
      resource.update permissions_attributes: group_permissions

      # Create sipity record
      workflow = Sipity::Workflow.joins(:permission_template)
                                 .where(permission_templates: { source_id: resource.admin_set_id }, active: true)
      workflow_state = Sipity::WorkflowState.where(workflow_id: workflow.first.id, name: 'deposited')
      Sipity::Entity.create!(proxy_for_global_id: resource.to_global_id.to_s,
                             workflow: workflow.first,
                             workflow_state: workflow_state.first)

      # get list of all files in unzipped proquest package
      unzipped_file_list = Dir.glob("#{unzipped_package_dir}/**/*.*")

      ordered_members = []
      listed_files.each do |f|
        logger.info("[#{id}] trying...#{f.to_s}")

        file_path = unzipped_file_list.find { |e| e.match(f.to_s) }
        if file_path.blank?
          logger.error("[#{id}] cannot find #{f.to_s}")
          next
        end

        if File.file?(file_path)
          file_set = ingest_proquest_file(parent: resource,
                                          resource: metadata.merge({ title: [f] }),
                                          f: file_path)
          ordered_members << file_set if file_set
        end
      end
      resource.ordered_members = ordered_members

      # Attach metadata file
      fileset_attrs = { 'title' => [File.basename(metadata_file_path)] }
      fileset = ingest_proquest_file(parent: resource, resource: fileset_attrs, f: metadata_file_path)

      # Force visibility to private since it seems to be saving as public
      fileset.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
      fileset.permissions_attributes = group_permissions
      fileset.save

      resource.ordered_members << fileset

      # delete zip file after files have been extracted and ingested successfully
      File.delete(package_path) if Rails.env != 'test'
    end

    def metadata_file_path(dir:)
      metadata_file = Dir.glob("#{dir}/*_DATA.xml")
      if metadata_file.count == 1
        metadata_file.first.to_s
      else
        logger.error("Error: #{dir} has #{metadata_file.count} xml file(s)")
        nil
      end
    end

    def ingest_proquest_file(parent: nil, resource: nil, f: nil)
      logger.info("[#{parent.id}] ingesting... #{f.to_s}")
      fileset_metadata = file_record(resource)

      fileset_metadata.except!('embargo_release_date', 'visibility_during_embargo', 'visibility_after_embargo') if fileset_metadata['embargo_release_date'].blank?
      file_set = FileSet.create(fileset_metadata)
      actor = Hyrax::Actors::FileSetActor.new(file_set, @depositor)
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
      visibility_during_embargo = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
      visibility_after_embargo = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
      embargo_release_date = ''
      visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC

      embargo_code = metadata.xpath('//DISS_submission/@embargo_code').text

      logger.info("[#{metadata_file}] embargo code: #{embargo_code}")

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

        embargo_release_date = '' if !embargo_release_date.blank? && embargo_release_date != current_date && embargo_release_date < current_date

        visibility = visibility_during_embargo unless embargo_release_date.blank?
      end

      logger.info("[#{metadata_file}] embargo release date: #{embargo_release_date}")

      title = metadata.xpath('//DISS_description/DISS_title').text

      creators = metadata.xpath('//DISS_submission/DISS_authorship/DISS_author[@type="primary"]/DISS_name').map do |creator|
        format_name(creator)
      end

      degree_granting_institution = metadata.xpath('//DISS_description/DISS_institution/DISS_inst_name').text

      keywords = metadata.xpath('//DISS_description/DISS_categorization/DISS_keyword').text.split(', ')
      keywords << metadata.xpath('//DISS_description/DISS_categorization/DISS_category/DISS_cat_desc').map(&:text)

      abstract = metadata.xpath('//DISS_content/DISS_abstract').text

      advisor = metadata.xpath('//DISS_description/DISS_advisor/DISS_name').map do |advise|
        "#{advise.xpath('DISS_surname').text}, #{advise.xpath('DISS_fname').text} #{advise.xpath('DISS_middle').text}"
      end

      committee_members = metadata.xpath('//DISS_description/DISS_cmte_member/DISS_name').map do |advise|
        format_name(advise)
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
                     'dnp' => 'Doctor of Nursing Practice' }
      if !degree_map[normalized_degree].blank?
        degree = DegreesService.label(degree_map[normalized_degree])
      else
        logger.warn("[#{metadata_file}] unknown degree: #{abbreviated_degree}")
        degree = abbreviated_degree
      end

      resource_type = if normalized_degree.in? ['ma', 'ms']
                        'Masters Thesis'
                      else
                        'Dissertation'
                      end

      department = metadata.xpath('//DISS_description/DISS_institution/DISS_inst_contact').text.strip
      affiliation = ProquestDepartmentMappingsService.standard_department_name(department) || department

      date_issued = metadata.xpath('//DISS_description/DISS_dates/DISS_comp_date').text
      date_issued = Date.strptime(date_issued, '%Y')

      graduation_year = (date_issued.year || @file_last_modified.year).to_s

      language = metadata.xpath('//DISS_description/DISS_categorization/DISS_language').text
      if language == 'en'
        language = MigrationHelper.get_language_uri(['eng'])
        language_label = LanguagesService.label(language) unless language.blank?
      end

      file_full << metadata.xpath('//DISS_content/DISS_binary').text
      file_full += metadata.xpath('//DISS_content/DISS_attachment').map do |file_name|
        file_name.xpath('DISS_file_name').text
      end

      work_attributes = {
        'title' => [title],
        'label' => title,
        'depositor' => @depositor.uid,
        'creators_attributes' => build_person_hash(creators, affiliation),
        'date_issued' => (Date.try(:edtf, date_issued.year) || date_issued.year).to_s,
        'abstract' => abstract.gsub(/\n/, '').strip,
        'advisors_attributes' => build_person_hash(advisor, nil),
        'dcmi_type' => dcmi_type,
        'degree' => degree,
        'degree_granting_institution' => degree_granting_institution,
        'graduation_year' => graduation_year,
        'language' => language,
        'language_label' => language_label,
        'rights_statement' => 'http://rightsstatements.org/vocab/InC-EDU/1.0/',
        'rights_statement_label' => 'In Copyright - Educational Use Permitted',
        'keyword' => keywords.flatten,
        'resource_type' => resource_type,
        'visibility' => visibility,
        'embargo_release_date' => (Date.try(:edtf, embargo_release_date.to_s)).to_s,
        'visibility_during_embargo' => visibility_during_embargo,
        'visibility_after_embargo' => visibility_after_embargo,
        'admin_set_id' => @admin_set_id
      }

      work_attributes.reject! { |_k, v| v.blank? }

      [work_attributes, file_full]
    end

    def build_person_hash(people, affiliation)
      person_hash = {}
      people.each_with_index do |person, index|
        person_hash[index.to_s] = { 'name' => person, 'affiliation' => affiliation, 'index' => index + 1 }
      end

      person_hash
    end

    def format_name(person)
      name_parts = []
      name_parts << person.xpath('DISS_surname').text
      name_parts << ("#{person.xpath('DISS_fname').text} #{person.xpath('DISS_middle').text}").strip
      name_parts << person.xpath('DISS_suffix').text
      name_parts.reject { |name| name.blank? }.join(', ')
    end

    # FileSets can include any metadata listed in BasicMetadata file
    def file_record(attrs)
      file_set = FileSet.new
      file_attributes = Hash.new

      # Singularize non-enumerable attributes and make sure enumerable attributes are arrays
      attrs.each do |k, v|
        if file_set.attributes.keys.member?(k.to_s)
          file_attributes[k] = if !file_set.attributes[k.to_s].respond_to?(:each) && file_attributes[k].respond_to?(:each)
                                 v.first
                               elsif file_set.attributes[k.to_s].respond_to?(:each) && !file_attributes[k].respond_to?(:each)
                                 Array(v)
                               else
                                 v
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

    def valid_extract?(extracted_files)
      # There should only be one _DATA.xml file
      metadata_file_match = extracted_files.keys.map { |file_name| file_name.match('_DATA.xml') }.compact
      # There should be at least one PDF file, but there could be more if there are supplemental materials
      pdf_file_match = extracted_files.keys.map { |file_name| file_name.match('.pdf') }.compact
      return true if metadata_file_match.size == 1 && pdf_file_match.size >= 1

      false
    end
  end
end
