# The default admin set and designated depositor must exist before running this script
namespace :migrate do
  require 'fileutils'
  require 'tasks/migration/migration_logging'
  require 'htmlentities'
  require 'tasks/migration/migration_constants'
  require 'csv'
  require 'yaml'

  # Maybe switch to auto-loading lib/tasks/migrate in environment.rb
  require 'tasks/migrate/services/mods_parser'

  desc 'batch migrate records from FOXML file'
  task :works, [:collection, :configuration_file, :mapping_file] => :environment do |t, args|

    puts "[#{Time.now.to_s}] Start migration of #{args[:collection]}"

    if AdminSet.where(title: ENV['DEFAULT_ADMIN_SET']).count != 0
      config = YAML.load_file(args[:configuration_file])
      collection_config = config[args[:collection]]
      @work_type = collection_config['work_type']
      @admin_set = collection_config['admin_set']
      @depositor = User.where(email: collection_config['depositor_email']).first
      @collection_name = collection_config['collection_name']
      @child_work_type = collection_config['child_work_type']

      # Store parent-child relationships
      @parent_hash = Hash.new {|h,k| h[k] = Array.new }
      # Store uuid/hyrax-id mappings for current collection
      @mapping = Hash.new

      # Hash of all binaries in storage directory
      @binary_hash = Hash.new
      File.open(collection_config['binaries']) do |file|
        file.each do |line|
          value = line.strip
          key = get_uuid_from_path(value)
          @binary_hash[key] = value
        end
      end

      # Hash of all .xml objects in storage directory
      @object_hash = Hash.new
      File.open(collection_config['objects']) do |file|
        file.each do |line|
          value = line.strip
          key = get_uuid_from_path(value)
          if !key.blank?
            @object_hash[key] = value
          end
        end
      end

      # Create file mapping new and old ids
      @csv_output = args[:mapping_file]
      if !File.exist?(@csv_output)
        @csv_output = File.new(@csv_output, 'w')
      end

      collection_ids_file = collection_config['collection_list']
      migrate_objects(collection_ids_file)
      if !@child_work_type.blank?
        attach_children
      end
    else
      puts 'The default admin set does not exist'
    end

    puts "[#{Time.now.to_s}] Finish migration of #{args[:collection]}"
  end

  def migrate_objects(collection_ids_file)
    collection_uuids = Array.new
    CSV.open(collection_ids_file) do |file|
      file.each do |line|
        collection_uuids.append(line[0].strip) unless line.blank?
      end
    end

    puts "Object count:  #{collection_uuids.count.to_s}"

    collection_uuids.each do |collection_uuid|
      uuid = get_uuid_from_path(collection_uuid)
      # Assuming uuid for metadata and binary are not the same
      # Skip file/binary metadata
      # solr returns column header; skip that, too
      if @binary_hash[uuid].blank? && !uuid.blank?
        metadata_fields = metadata(@object_hash[uuid])

        puts "Number of files: #{metadata_fields[:files].count.to_s if !metadata_fields[:files].blank?}"

        resource = metadata_fields[:resource]
        resource.save!

        @mapping[uuid] = resource.id

        # Record old and new ids for works
        CSV.open(@csv_output, 'a+') do |csv|
          csv << [uuid, resource.id]
        end

        # Ingest files for work if at least one is found
        if !metadata_fields[:files].blank? && !metadata_fields[:files][0].blank?
          ingest_files(resource: resource, files: metadata_fields[:files])
        end
      end
    end
  end

  def ingest_files(parent: nil, resource: nil, files: [])
    ordered_members = []

    files.each do |f|
      # Get file/binary object metadata
      file_metadata = metadata(f)
      file_set = ingest_file(parent: resource, resource: file_metadata[:resource], f: file_metadata[:files][0])
      ordered_members << file_set if file_set
    end

    resource.ordered_members = ordered_members
  end

  def ingest_file(parent: nil, resource: nil, f: nil)
    file_set = FileSet.create(resource)
    actor = Hyrax::Actors::FileSetActor.new(file_set, @depositor)
    actor.create_metadata(resource.slice(:visibility, :visibility_during_lease, :visibility_after_lease,
                                          :lease_expiration_date, :embargo_release_date, :visibility_during_embargo,
                                          :visibility_after_embargo))
    actor.create_content(File.open(f))
    actor.attach_to_work(parent)

    # Record old and new ids for files
    CSV.open(@csv_output, 'a+') do |csv|
      csv << [get_uuid_from_path(f), file_set.id]
    end

    file_set
  end

  def metadata(file)
    work_attributes = Migrate::Services::ModsParser.new(file, @object_hash, @binary_hash).parse

    if work_attributes['contained_files']
      { resource: work_record(work_attributes), files: work_attributes['file_full'] }
    else
      resource = Hash.new(0)

      { resource: file_record(work_attributes, resource), files: work_attributes['file_full'] }
    end
  end

  def work_record(work_attributes)
    if !@child_work_type.blank? && work_attributes['cdr_model_type'] != 'aggregate'
      resource = @child_work_type.singularize.classify.constantize.new
    else
      resource = @work_type.singularize.classify.constantize.new
    end
    resource.creator = work_attributes['creator']
    resource.depositor = @depositor.uid
    resource.save

    # Singularize non-enumerable attributes
    work_attributes.each do |k,v|
      if resource.attributes.keys.member?(k.to_s) && !resource.attributes[k.to_s].respond_to?(:each) && work_attributes[k].respond_to?(:each)
        work_attributes[k] = v.first
      else
        work_attributes[k] = v
      end
    end

    # Only keep attributes which apply to the given work type
    resource.attributes = work_attributes.reject{|k,v| !resource.attributes.keys.member?(k.to_s)}

    resource.rights_statement = ['http://rightsstatements.org/vocab/InC-EDU/1.0/']
    resource.visibility = work_attributes['visibility']
    unless work_attributes['embargo_release_date'].blank?
    resource.embargo_release_date = work_attributes['embargo_release_date']
    resource.visibility_during_embargo = work_attributes['visibility_during_embargo']
    resource.visibility_after_embargo = work_attributes['visibility_after_embargo']
    end
    resource.admin_set_id = work_attributes['admin_set_id']
    if !@collection_name.blank? && !work_attributes['member_of_collections'].first.blank?
      resource.member_of_collections = work_attributes['member_of_collections']
    end

    resource
  end

  # FileSets can include any metadata listed in BasicMetadata file
  def file_record(work_attributes, resource)
    file_set = FileSet.new
    # Singularize non-enumerable attributes
    work_attributes.each do |k,v|
      if file_set.attributes.keys.member?(k.to_s) && !file_set.attributes[k.to_s].respond_to?(:each) && work_attributes[k].respond_to?(:each)
        work_attributes[k] = v.first
      else
        work_attributes[k] = v
      end
    end
    resource[:creator] = work_attributes['creator']
    resource[:depositor] = @depositor.uid
    resource[:label] = work_attributes['label']
    resource[:title] = work_attributes['title']
    resource[:bibliographic_citation] =  work_attributes['bibliographic_citation']
    resource[:keyword] =  work_attributes['keyword']
    resource[:date_created] = work_attributes['date_created']
    resource[:date_modified] = work_attributes['date_modified']
    resource[:date_uploaded] = work_attributes['date_uploaded']
    resource[:contributor] = work_attributes['contributor']
    resource[:description] = work_attributes['description']
    resource[:identifier] = work_attributes['identifier']
    resource[:related_url] = work_attributes['related_url']
    resource[:publisher] = work_attributes['publisher']
    resource[:subject] = work_attributes['subjects']
    resource[:resource_type] = work_attributes['resource_type']
    resource[:language] = work_attributes['language']
    resource[:based_near] = work_attributes['based_near']
    resource[:source] = work_attributes['source']
    resource[:license] = work_attributes['license']
    resource[:rights_statement] = ['rights_statement']
    resource[:visibility] = work_attributes['visibility']
    unless work_attributes['embargo_release_date'].blank?
      resource[:embargo_release_date] = work_attributes['embargo_release_date']
      resource[:visibility_during_embargo] = work_attributes['visibility_during_embargo']
      resource[:visibility_after_embargo] = work_attributes['visibility_after_embargo']
    end

    resource
  end

  def get_uuid_from_path(path)
    path.slice(/\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
  end

  def attach_children
    @parent_hash.each do |parent_id, children|
      hyrax_id = @mapping[parent_id]
      parent = @work_type.singularize.classify.constantize.find(hyrax_id)
      children.each do |child|
        if @mapping[child]
          parent.ordered_members << ActiveFedora::Base.find(@mapping[child])
          parent.members << ActiveFedora::Base.find(@mapping[child])
        end
      end
      parent.save!
    end
  end
end
