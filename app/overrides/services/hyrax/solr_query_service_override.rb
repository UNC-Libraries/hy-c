# [hyc-override] changes GET request to POST to allow for larger query size, and increase page size from default 10
# https://github.com/samvera/hyrax/blob/v3.5.0/app/services/hyrax/solr_query_service.rb
# frozen_string_literal: true
Hyrax::SolrQueryService.module_eval do
  def get
    solr_service.post(build, rows: 1000)
  end
end
