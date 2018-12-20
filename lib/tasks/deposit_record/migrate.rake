namespace :deposit_record do
  require 'fileutils'
  require 'csv'
  require 'yaml'
  require 'tasks/migration_helper'

  desc 'batch migrate deposit records'
  task :migrate, [:configuration_file, :mapping_file] => :environment do |t, args|
    start_time = Time.now
    puts "[#{start_time.to_s}] Start migration of deposit records"

    config = YAML.load_file(args[:configuration_file])
    collection_config = config['deposit_record']

    @depositor = User.where(email: collection_config['depositor_email']).first

    # Hash of all binaries in storage directory
    @binary_hash = Hash.new
    MigrationHelper.create_filepath_hash(collection_config['binaries'], @binary_hash)

    # Hash of all .xml objects in storage directory
    @object_hash = Hash.new
    MigrationHelper.create_filepath_hash(collection_config['objects'], @object_hash)

    # Hash of all premis files in storage directory
    @premis_hash = Hash.new
    MigrationHelper.create_filepath_hash(collection_config['premis'], @premis_hash)

    id_mapper = Migrate::Services::IdMapper.new(args[:mapping_file])

    collection_uuids = MigrationHelper.get_collection_uuids(collection_config['collection_list'])

    puts "Object count:  #{collection_uuids.count.to_s}"

    collection_uuids.each do |uuid|
      puts "[#{start_time.to_s}] Start migration of #{uuid}"

      record_attributes = deposit_record_metadata(@object_hash[uuid])
      deposit_record = DepositRecord.new(record_attributes[:resource])

      # add manifest files
      puts "manifest count: #{record_attributes[:manifests].count}"
      deposit_record[:manifest] = create_fedora_file_record(record_attributes[:manifests], @binary_hash, deposit_record)

      # add premis files
      puts "premis count: #{record_attributes[:premis].count}"
      deposit_record[:premis] = create_fedora_file_record(record_attributes[:premis], @premis_hash, deposit_record)

      deposit_record.save

      id_mapper.add_row([MigrationHelper.get_uuid_from_path(record_attributes[:resource][:identifier]), deposit_record.id])

      puts "[#{Time.now.to_s}] Completed migration of #{uuid} in #{Time.now-start_time} seconds"
    end

    end_time = Time.now
    puts "[#{end_time.to_s}] Completed migration of deposit records in #{end_time-start_time} seconds"
  end


  # parse metadata
  def deposit_record_metadata(metadata_file)
    record_attributes = Hash.new

    file = File.open(metadata_file)
    metadata = Nokogiri::XML(file)
    file.close

    record_attributes[:title] = metadata.xpath("//foxml:datastream[@ID='DC']//oai_dc:dc/dc:title", MigrationConstants::NS).text
    record_attributes[:identifier] = metadata.xpath("//foxml:datastream[@ID='DC']//oai_dc:dc/dc:identifier", MigrationConstants::NS).text
    record_attributes[:deposit_method] = metadata.xpath("//rdf:RDF/rdf:Description/*[local-name() = 'depositMethod']", MigrationConstants::NS).text
    record_attributes[:deposit_package_subtype] = metadata.xpath("//rdf:RDF/rdf:Description/*[local-name() = 'depositPackageSubType']", MigrationConstants::NS).text
    record_attributes[:deposit_package_type] = metadata.xpath("//rdf:RDF/rdf:Description/*[local-name() = 'depositPackageType']", MigrationConstants::NS).text
    record_attributes[:deposited_by] = metadata.xpath("//rdf:RDF/rdf:Description/*[local-name() = 'depositedBy']", MigrationConstants::NS).text
    record_attributes[:audit_process] = metadata.xpath("//audit:auditTrail/audit:record/audit:process", MigrationConstants::NS).text
    record_attributes[:audit_action] = metadata.xpath("//audit:auditTrail/audit:record/audit:action", MigrationConstants::NS).text
    record_attributes[:audit_component_id] = metadata.xpath("//audit:auditTrail/audit:record/audit:componentID", MigrationConstants::NS).text
    record_attributes[:audit_responsibility] = metadata.xpath("//audit:auditTrail/audit:record/audit:responsibility", MigrationConstants::NS).text
    record_attributes[:audit_date] = metadata.xpath("//audit:auditTrail/audit:record/audit:date", MigrationConstants::NS).text
    record_attributes[:audit_justification] = metadata.xpath("//audit:auditTrail/audit:record/audit:justification", MigrationConstants::NS).text

    # Find manifest files
    manifests = metadata.xpath("//foxml:datastream[contains(@ID, 'DATA_MANIFEST')]", MigrationConstants::NS)

    # Find premis files
    premis_files = metadata.xpath("//foxml:datastream[contains(@ID, 'MD_EVENTS')]", MigrationConstants::NS)

    { resource: record_attributes.reject!{|k,v| v.blank?}, manifests: manifests, premis: premis_files }
  end


  private

    def create_fedora_file_record(files, binary_hash, parent)
      uris = Array.new

      files.each do |mods|
        attrs = Hash.new
        id = mods.xpath("foxml:datastreamVersion/foxml:contentLocation/@REF", MigrationConstants::NS).text
        attrs['title'] = mods.xpath("foxml:datastreamVersion/@ID", MigrationConstants::NS).text
        attrs['date_created'] = mods.xpath("foxml:datastreamVersion/@CREATED", MigrationConstants::NS).text
        attrs['mime_type'] = mods.xpath("foxml:datastreamVersion/@MIMETYPE", MigrationConstants::NS).text

        binary_file = binary_hash[MigrationHelper.get_uuid_from_path(id)]

        file = FedoraOnlyFile.new(attrs)
        file.deposit_record = parent

        file.file.content = File.open(binary_file)
        file.file.mime_type = attrs['mime_type']
        file.file.original_name = attrs['title']

        file.save

        uris << file.uri
      end

      uris
    end
end
