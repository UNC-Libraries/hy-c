# [hyc-override] changes GET request to POST to allow for larger query size
# https://github.com/samvera/hyrax/blob/v3.5.0/app/services/hyrax/solr_query_service.rb
# frozen_string_literal: true
Hyrax::SolrQueryService.module_eval do
  def get(*args)
    solr_service.post(build, *args)
  end
end
