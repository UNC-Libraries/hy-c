# this rake task is not being moved to a service module

namespace :migrate do
  require 'fileutils'
  require 'tasks/migration/migration_logging'
  require 'htmlentities'
  require 'tasks/migration/migration_constants'
  require 'csv'
  require 'yaml'

  # Maybe switch to auto-loading lib/tasks/migrate in environment.rb
  require 'tasks/migrate/services/child_work_parser'
  require 'tasks/migrate/services/ingest_service'
  require 'tasks/migration_helper'

  desc 'batch migrate records from FOXML file'
  task :works, [:collection, :configuration_file, :output_dir] => :environment do |_t, args|
    start_time = Time.now
    puts "[#{start_time.to_s}] Start migration of #{args[:collection]}"

    config = YAML.load_file(args[:configuration_file])
    collection_config = config[args[:collection]]

    # The default admin set and designated depositor must exist before running this script
    if AdminSet.where(title: ENV['DEFAULT_ADMIN_SET']).count != 0 &&
        User.where(email: collection_config['depositor_email']).count > 0
      @depositor = User.where(email: collection_config['depositor_email']).first

      puts "[#{Time.now.to_s}] create binary hash"
      # Hash of all binaries in storage directory
      @binary_hash = Hash.new
      MigrationHelper.create_filepath_hash(collection_config['binaries'], @binary_hash)

      puts "[#{Time.now.to_s}] create object hash"
      # Hash of all .xml objects in storage directory
      @object_hash = Hash.new
      MigrationHelper.create_filepath_hash(collection_config['objects'], @object_hash)

      puts "[#{Time.now.to_s}] create premis hash"
      # Hash of all premis files in storage directory
      @premis_hash = Hash.new
      MigrationHelper.create_filepath_hash(collection_config['premis'], @premis_hash)

      puts "[#{Time.now.to_s}] create deposit record hash"
      # Hash of all deposit record ids
      @deposit_record_hash = Hash.new
      CSV.foreach(collection_config['deposit_records']) do |row|
        @deposit_record_hash[row[0]] = row[1]
      end
      puts "[#{Time.now.to_s}] completed creation of hashes"

      # Create the output directory if it does not yet exist
      FileUtils.mkdir(args[:output_dir]) unless File.exist?(args[:output_dir])

      if !collection_config['child_work_type'].blank?
        Migrate::Services::ChildWorkParser.new(@object_hash,
                                               collection_config,
                                               args[:output_dir],
                                               args[:collection]).find_children
      end

      Migrate::Services::IngestService.new(collection_config,
                                           @object_hash,
                                           @binary_hash,
                                           @premis_hash,
                                           @deposit_record_hash,
                                           args[:output_dir],
                                           @depositor,
                                           args[:collection]).ingest_records
    else
      puts 'The default admin set or specified depositor does not exist'
    end

    end_time = Time.now
    puts "[#{end_time.to_s}] Completed migration of #{args[:collection]} in #{end_time - start_time} seconds"
  end
end
