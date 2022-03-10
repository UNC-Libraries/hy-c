# Cribbing from https://github.com/samvera/hyrax/blob/v2.9.6/app/services/hyrax/adapters/nesting_index_adapter.rb
module HycFedoraCrawlerService
  def self.person_fields
    [:advisors, :arrangers, :composers, :contributors, :creators, :project_directors,
     :researchers, :reviewers, :translators]
  end

  def self.crawl_for_affiliations
    Rails.logger.info('Beginning to crawl Fedora for affiliations')
    ActiveFedora::Base.descendant_uris(ActiveFedora.fedora.base_uri, exclude_uri: true).each do |uri|
      Rails.logger.debug("Starting to find affiliations for uri: #{uri}")
      id = ActiveFedora::Base.uri_to_id(uri)
      object = ActiveFedora::Base.find(id)
      # Collections respond to the person fields, but don't actually have person objects
      next if object.instance_of?(Collection)

      next unless object_has_person_field?(object)

      url = Rails.application.routes.url_helpers.url_for(object)
      affiliations = all_person_affiliations(object).sort
      yield(id, url, affiliations) unless affiliations.compact.empty?
    end
  end

  def self.create_csv_of_umappable_affiliations
    csv_directory = Rails.root.join(ENV['DATA_STORAGE'], 'reports')
    FileUtils.mkdir_p(csv_directory) unless File.exist?(csv_directory)
    csv_file_path = Rails.root.join(ENV['DATA_STORAGE'], 'reports', 'umappable_affiliations.csv')
    headers = ['object_id', 'url', 'affiliations']

    CSV.open(csv_file_path, 'w') do |csv|
      csv << headers
      crawl_for_affiliations do |document_id, url, affiliations|
        unmappable_affiliations = unmappable_affiliations(affiliations)
        Rails.logger.debug("Saving object info to csv. url: #{url}") unless unmappable_affiliations.empty?
        csv << [document_id, url, unmappable_affiliations] unless unmappable_affiliations.empty?
      end
    end
  end

  def self.object_has_person_field?(object)
    person_fields.map { |field| object.respond_to?(field) }.include?(true)
  end

  def self.person_affiliations_by_type(object, person_type)
    people_object = object.try(person_type)
    return unless people_object && !people_object.empty?

    people_object.map { |person| person.attributes['affiliation'].to_a }.compact.flatten
  end

  def self.unmappable_affiliations(affiliations)
    affiliations.map { |affil| DepartmentsService.label(affil) ? nil : affil }.compact
  end

  def self.all_person_affiliations(object)
    person_fields.map do |field|
      affiliations = person_affiliations_by_type(object, field)
      affiliations unless affiliations.nil? || affiliations.compact.empty?
    end.compact.flatten
  end
end
