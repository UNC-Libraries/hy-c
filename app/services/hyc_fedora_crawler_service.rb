# Cribbing from https://github.com/samvera/hyrax/blob/v2.9.6/app/services/hyrax/adapters/nesting_index_adapter.rb
module HycFedoraCrawlerService
  # include Hyrax::Adapters::NestingIndexAdapter
  def self.crawl_for_affiliations
    ActiveFedora::Base.descendant_uris(ActiveFedora.fedora.base_uri, exclude_uri: true).each do |uri|
      id = ActiveFedora::Base.uri_to_id(uri)
      object = ActiveFedora::Base.find(id)
      creator_affiliations = []
      creator_affiliations = object.creators.map { |creator| creator.attributes['affiliation'] } if object.try(:creators) && !object.creators.empty?

      yield(id, creator_affiliations) unless creator_affiliations.empty?
    end
  end
end
