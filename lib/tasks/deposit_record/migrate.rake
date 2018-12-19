namespace :deposit_record do
  require 'fileutils'
  require 'csv'
  require 'yaml'

  desc 'batch migrate deposit records'
  task :migrate, [:configuration_file, :mapping_file] => :environment do |t, args|
    start_time = Time.now
    puts "[#{start_time.to_s}] Start migration of deposit records"

    config = YAML.load_file(args[:configuration_file])
    collection_config = config['deposit_record']

    @depositor = User.where(email: collection_config['depositor_email']).first

    # Hash of all binaries in storage directory
    @binary_hash = Hash.new
    create_filepath_hash(collection_config['binaries'], @binary_hash)

    # Hash of all .xml objects in storage directory
    @object_hash = Hash.new
    create_filepath_hash(collection_config['objects'], @object_hash)

    # Hash of all premis files in storage directory
    @premis_hash = Hash.new
    create_filepath_hash(collection_config['premis'], @premis_hash)

    id_mapper = Migrate::Services::IdMapper.new(args[:mapping_file])

    collection_uuids = get_collection_uuids(collection_config['collection_list'])

    puts "Object count:  #{collection_uuids.count.to_s}"

    collection_uuids.each do |uuid|
      puts "[#{start_time.to_s}] Start migration of #{uuid}"

      record_attributes = record_metadata(@object_hash[uuid])
      deposit_record = DepositRecord.new(id: ::Noid::Rails::Service.new.minter.mint)
      deposit_record.attributes = record_attributes[:resource]
      deposit_record.save

      id_mapper.add_row([get_uuid_from_path(record_attributes[:resource][:identifier]), deposit_record.id])

      # add files
      record_attributes[:manifests].each do |manifest_mods|
        manifest_attrs = Hash.new
        manifest_id = manifest_mods.xpath("foxml:datastreamVersion/foxml:contentLocation/@REF", MigrationConstants::NS).text
        manifest_attrs['title'] = manifest_mods.xpath("foxml:datastreamVersion/@ID", MigrationConstants::NS).text
        manifest_attrs['date_created'] = manifest_mods.xpath("foxml:datastreamVersion/@CREATED", MigrationConstants::NS).text
        manifest_attrs['mime_type'] = manifest_mods.xpath("foxml:datastreamVersion/@MIMETYPE", MigrationConstants::NS).text

        binary_file = @binary_hash[get_uuid_from_path(manifest_id)]

        manifest = FedoraOnlyFile.new(manifest_attrs)
        manifest.deposit_record = deposit_record

        manifest.file.content = File.open(binary_file)
        manifest.file.mime_type = manifest_attrs['mime_type']
        manifest.file.original_name = manifest_attrs['title']

        manifest.save
      end

      # add premis files
      record_attributes[:premis].each do |premis_mods|
        premis_attrs = Hash.new
        premis_id = premis_mods.xpath("foxml:datastreamVersion/foxml:contentLocation/@REF", MigrationConstants::NS).text
        premis_attrs['title'] = premis_mods.xpath("foxml:datastreamVersion/@ID", MigrationConstants::NS).text
        premis_attrs['date_created'] = premis_mods.xpath("foxml:datastreamVersion/@CREATED", MigrationConstants::NS).text
        premis_attrs['mime_type'] = premis_mods.xpath("foxml:datastreamVersion/@MIMETYPE", MigrationConstants::NS).text

        binary_file = @binary_hash[get_uuid_from_path(premis_id)]

        premis = FedoraOnlyFile.new(premis_attrs)
        premis.deposit_record = deposit_record

        premis.file.content = File.open(binary_file)
        premis.file.mime_type = premis_attrs['mime_type']
        premis.file.original_name = premis_attrs['title']

        premis.save
      end

      puts "[#{Time.now.to_s}] Completed migration of #{uuid} in #{Time.now-start_time} seconds"
    end

    end_time = Time.now
    puts "[#{end_time.to_s}] Completed migration of deposit records in #{end_time-start_time} seconds"
  end


  # parse metadata
  def record_metadata(metadata_file)
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

    def get_uuid_from_path(path)
      path.slice(/\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
    end

    def create_filepath_hash(filename, hash)
      File.open(filename) do |file|
        file.each do |line|
          value = line.strip
          key = get_uuid_from_path(value)
          if !key.blank?
            hash[key] = value
          end
        end
      end
    end

    def get_collection_uuids(collection_ids_file)
      collection_uuids = Array.new
      File.open(collection_ids_file) do |file|
        file.each do |line|
          if !line.blank? && !get_uuid_from_path(line.strip).blank?
            collection_uuids.append(get_uuid_from_path(line.strip))
          end
        end
      end

      collection_uuids
    end
end
