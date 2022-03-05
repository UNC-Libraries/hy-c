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
      affiliations = []
      person_fields.each do |field|
        affils = person_affiliations(object, field)
        affiliations << affils unless affils.nil?
      end
      yield(id, affiliations.flatten!) unless affiliations.empty?
    end
  end

  def self.person_affiliations(object, person_type)
    people_object = object.try(person_type)
    people_object.map { |person| person.attributes['affiliation'] } if people_object && !people_object.empty?
  end
end
