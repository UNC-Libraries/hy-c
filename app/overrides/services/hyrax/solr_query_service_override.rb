# [hyc-override] changes GET request to POST to allow for larger query size
# https://github.com/samvera/hyrax/blob/v3.5.0/app/services/hyrax/solr_query_service.rb
# frozen_string_literal: true
Hyrax::SolrQueryService.module_eval do
  def get(**args)
    solr_service.post(build, **args)
  end

  ## @todo the following method has been added on the main hyrax branch, but is not yet in a hyrax release.
  # This can be removed once hyrax is updated.
  # @param from [String] field on the documents matched by +query+
  # @param to [String] field on the documents to return
  # @param query [String, #build] the query selecting the documents to join from
  # @return [SolrQueryService] the existing service with a join query appended
  def with_join(from:, to:, query:)
    inner_query = query.respond_to?(:build) ? query.build : query
    @query += ["{!join from=#{from} to=#{to} v='#{inner_query}'}"]
    self
  end
end
