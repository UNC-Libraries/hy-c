namespace :migrate do
  require 'fileutils'
  require 'tasks/migration/migration_logging'
  require 'htmlentities'
  require 'tasks/migration/migration_constants'
  require 'csv'
  require 'yaml'

  # Maybe switch to auto-loading lib/tasks/migrate in environment.rb
  require 'tasks/migrate/services/ingest_service'

  desc 'batch migrate records from FOXML file'
  task :works, [:collection, :configuration_file, :mapping_file] => :environment do |t, args|

    puts "[#{Time.now.to_s}] Start migration of #{args[:collection]}"

    config = YAML.load_file(args[:configuration_file])
    collection_config = config[args[:collection]]

    # The default admin set and designated depositor must exist before running this script
    if AdminSet.where(title: ENV['DEFAULT_ADMIN_SET']).count != 0 &&
        User.where(email: collection_config['depositor_email']).count > 0
      @depositor = User.where(email: collection_config['depositor_email']).first

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

      Migrate::Services::IngestService.new(collection_config,
                                           @object_hash,
                                           @binary_hash,
                                           args[:mapping_file],
                                           @depositor).ingest_records
    else
      puts 'The default admin set or specified depositor does not exist'
    end

    puts "[#{Time.now.to_s}] Finish migration of #{args[:collection]}"
  end

  private

    def get_uuid_from_path(path)
      path.slice(/\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
    end
end
