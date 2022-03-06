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
      next unless has_person_field?(object)

      affiliations = all_person_affiliations(object)

      yield(id, affiliations) unless affiliations.empty?
    end
  end

  # rubocop:disable Naming/PredicateName
  def self.has_person_field?(object)
    person_fields.map { |field| object.respond_to?(field) }.include?(true)
  end
  # rubocop:enable Naming/PredicateName

  def self.person_affiliations_by_type(object, person_type)
    people_object = object.try(person_type)
    people_object.map { |person| person.attributes['affiliation'] } if people_object && !people_object.empty?
  end

  def self.all_person_affiliations(object)
    person_fields.map do |field|
      affiliations = person_affiliations_by_type(object, field)
      affiliations unless affiliations.nil?
    end.compact.flatten
  end
end
