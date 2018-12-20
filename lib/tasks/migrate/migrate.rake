namespace :migrate do
  require 'fileutils'
  require 'tasks/migration/migration_logging'
  require 'htmlentities'
  require 'tasks/migration/migration_constants'
  require 'csv'
  require 'yaml'

  # Maybe switch to auto-loading lib/tasks/migrate in environment.rb
  require 'tasks/migrate/services/ingest_service'
  require 'tasks/migration_helper'

  desc 'batch migrate records from FOXML file'
  task :works, [:collection, :configuration_file, :mapping_file] => :environment do |t, args|

    start_time = Time.now
    puts "[#{start_time.to_s}] Start migration of #{args[:collection]}"

    config = YAML.load_file(args[:configuration_file])
    collection_config = config[args[:collection]]

    # The default admin set and designated depositor must exist before running this script
    if AdminSet.where(title: ENV['DEFAULT_ADMIN_SET']).count != 0 &&
        User.where(email: collection_config['depositor_email']).count > 0
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

      Migrate::Services::IngestService.new(collection_config,
                                           @object_hash,
                                           @binary_hash,
                                           @premis_hash,
                                           args[:mapping_file],
                                           @depositor).ingest_records
    else
      puts 'The default admin set or specified depositor does not exist'
    end

    end_time = Time.now
    puts "[#{end_time.to_s}] Completed migration of #{args[:collection]} in #{end_time-start_time} seconds"
  end
end
