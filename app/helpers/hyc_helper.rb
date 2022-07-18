# Include hyc-specific helper code here instead of in the HyraxHelper to avoid circular dependencies
module HycHelper
  def language_links(options)
    language_link_array = options[:value].map do |lang|
      lang_label = LanguagesService.label(lang)
      link_to lang_label, main_app.search_catalog_path(f: { language_sim: [lang] }) unless lang_label.nil?
    end

    if language_link_array.compact.blank?
      nil
    else
      to_sentence(language_link_array)
    end
  end

  def language_links_facets(options)
    lang_label = LanguagesService.label(options)
    options = lang_label unless lang_label.nil?
    options
  end

  def redirect_lookup(column, id)
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
  def as_redirect_hash(id, new_path)
    return nil if id.nil? || new_path.nil?

    { 'uuid' => id, 'new_path' => new_path }
  end

  # rubocop:disable Style/ClassVars
  # Get the hash which maps old boxc uuids to new hyc paths
  def redirect_uuid_to_new_path_mappings
    @@uuid_to_new_path ||= begin
      mapping = {}
      CSV.foreach(redirect_mapping_file_path, headers: true) do |row|
        mapping[row[0]] = row[1]
      end
      mapping
    end
  end

  # Get the hash which maps new hyc paths to old boxc uuids
  def redirect_new_id_to_uuid_mappings
    @@new_id_to_uuid ||= begin
      mapping = {}
      CSV.foreach(redirect_mapping_file_path, headers: true) do |row|
        new_id = row[1].split('/')[-1]
        mapping[new_id] = row[0]
      end
      mapping
    end
  end

  def self.clear_redirect_mapping
    @@new_id_to_uuid = nil
    @@uuid_to_new_path = nil
  end
  # rubocop:enable Style/ClassVars

  # Configured path to redirect csv file
  def redirect_mapping_file_path
    if ENV.has_key?('REDIRECT_FILE_PATH') && File.exist?(ENV['REDIRECT_FILE_PATH'])
      ENV['REDIRECT_FILE_PATH']
    else
      Rails.root.join('lib', 'redirects', 'redirect_uuids.csv')
    end
  end

  def get_work_url(model, id)
    Rails.application.routes.url_helpers.send("#{Hyrax::Name.new(model).singular_route_key}_url", id)
  end

  def sort_people_by_index(values)
    Array(values.sort_by { |person| person.split('||').first.split(':').last.to_i })
  end
end
