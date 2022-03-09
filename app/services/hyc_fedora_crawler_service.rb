# Cribbing from https://github.com/samvera/hyrax/blob/v2.9.6/app/services/hyrax/adapters/nesting_index_adapter.rb
module HycFedoraCrawlerService
  def self.person_fields
    [:advisors, :arrangers, :composers, :contributors, :creators, :project_directors,
     :researchers, :reviewers, :translators]
  end

  def self.crawl_for_affiliations
    ActiveFedora::Base.descendant_uris(ActiveFedora.fedora.base_uri, exclude_uri: true).each do |uri|
      id = ActiveFedora::Base.uri_to_id(uri)
      object = ActiveFedora::Base.find(id)
      next unless object_has_person_field?(object)

      # "#{ENV['HYRAX_HOST']}/concern/#{object.class.name.underscore}s/#{object.id}"
      affiliations = all_person_affiliations(object).sort
      yield(id, affiliations) unless affiliations.compact.empty?
    end
  end

  def self.create_csv_of_umappable_affiliations
    csv_directory = Rails.root.join(ENV['DATA_STORAGE'], 'reports')
    FileUtils.mkdir_p(csv_directory) unless File.exist?(csv_directory)
    csv_file_path = Rails.root.join(ENV['DATA_STORAGE'], 'reports', 'umappable_affiliations.csv')
    headers = ['object_id', 'affiliations']

    CSV.open(csv_file_path, 'w') do |csv|
      csv << headers
      crawl_for_affiliations do |document_id, affiliations|
        csv << [document_id, affiliations]
      end
    end
  end

  def self.object_has_person_field?(object)
    person_fields.map { |field| object.respond_to?(field) }.include?(true)
  end

  def self.person_affiliations_by_type(object, person_type)
    people_object = object.try(person_type)
    return unless people_object && !people_object.empty?

    people_object.map do |person|
      affil = person.attributes['affiliation']
      affil.to_a unless affil.empty?
    end
  end

  def self.all_person_affiliations(object)
    person_fields.map do |field|
      affiliations = person_affiliations_by_type(object, field)
      affiliations unless affiliations.nil? || affiliations.compact.empty?
    end.compact.flatten
  end
end
