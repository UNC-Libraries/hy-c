# [hyc-override] Hyrax 3.4.1 changes GET request to POST to allow for larger query size
# https://github.com/samvera/hyrax/blob/v3.4.2/app/services/hyrax/solr_query_service.rb
# frozen_string_literal: true
Hyrax::SolrQueryService.module_eval do
  def get
    solr_service.post(build)
  end
end
