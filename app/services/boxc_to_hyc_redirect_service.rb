# Service which assist with redirects from old boxc ids to current hyc object
class BoxcToHycRedirectService
  # Retrieve redirect mapping based on the provided column and id
  # column - column to search, can be uuid or new_path
  # id - value to search for
  def self.redirect_lookup(column, id)
    case column
    when 'uuid'
      new_path = redirect_uuid_to_new_path_mappings[id]
      as_redirect_hash(id, new_path)
    when 'new_path'
      exact_id = id.split('/')[-1]
      uuid = redirect_new_id_to_uuid_mappings[exact_id]
      new_path = redirect_uuid_to_new_path_mappings[uuid]
      as_redirect_hash(uuid, new_path)
    else
      raise ArgumentError, 'Valid columns are uuid and new_path'
    end
  end

  # Format the redirect info as a hash
  def self.as_redirect_hash(id, new_path)
    return nil if id.nil? || new_path.nil?

    { 'uuid' => id, 'new_path' => new_path }
  end

  # Get the hash which maps old boxc uuids to new hyc paths
  def self.redirect_uuid_to_new_path_mappings
    Rails.cache.fetch('boxc_to_hyc_redirect_uuid_to_new_path_mappings') do
      mapping = {}
      CSV.foreach(redirect_mapping_file_path, headers: true) do |row|
        mapping[row[0]] = row[1]
      end
      mapping
    end
  end

  # Get the hash which maps new hyc paths to old boxc uuids
  def self.redirect_new_id_to_uuid_mappings
    Rails.cache.fetch('boxc_to_hyc_redirect_new_id_to_uuid_mappings') do
      mapping = {}
      CSV.foreach(redirect_mapping_file_path, headers: true) do |row|
        new_id = row[1].split('/')[-1]
        mapping[new_id] = row[0]
      end
      mapping
    end
  end

  # Configured path to redirect csv file
  def self.redirect_mapping_file_path
    if ENV.has_key?('REDIRECT_FILE_PATH') && File.exist?(ENV['REDIRECT_FILE_PATH'])
      ENV['REDIRECT_FILE_PATH']
    else
      Rails.root.join('lib', 'redirects', 'redirect_uuids.csv')
    end
  end
end
