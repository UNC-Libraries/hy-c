# Include hyc-specific helper code here instead of in the HyraxHelper to avoid circular dependencies
module HycHelper
  def language_links(options)
    language_link_array = options[:value].map do |lang|
      lang_label = LanguagesService.label(lang)
      if !lang_label.nil?
        link_to lang_label, main_app.search_catalog_path(f: { language_sim: [lang] })
      end
    end

    if language_link_array.compact.blank?
      nil
    else
      to_sentence(language_link_array)
    end
  end

  def language_links_facets(options)
    lang_label = LanguagesService.label(options)
    unless lang_label.nil?
      options = lang_label
    end
    options
  end

  def redirect_lookup(column, id)
    redirect_uuids = if ENV.has_key?('REDIRECT_FILE_PATH') && File.exist?(ENV['REDIRECT_FILE_PATH'])
                       File.read(ENV['REDIRECT_FILE_PATH'])
                     else
                       File.read(Rails.root.join('lib', 'redirects', 'redirect_uuids.csv'))
                     end

    csv = CSV.parse(redirect_uuids, headers: true)
    csv.find { |row| row[column].match(id) }
  end

  def get_work_url(model, id)
    Rails.application.routes.url_helpers.send(Hyrax::Name.new(model).singular_route_key + "_url", id)
  end

  def sort_people_by_index(values)
    Array(values.sort_by { |person| person.split('||').first.split(':').last.to_i })
  end
end
