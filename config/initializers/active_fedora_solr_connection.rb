# frozen_string_literal: true

require 'faraday/net_http_persistent'

Rails.application.config.after_initialize do
  ActiveFedora.solr_config[:adapter] = :net_http_persistent
  ActiveFedora.solr_config[:open_timeout] ||= ENV.fetch('SOLR_OPEN_TIMEOUT', 2).to_i
  ActiveFedora.solr_config[:timeout] ||= ENV.fetch('SOLR_TIMEOUT', 5).to_i

  # ActiveFedora caches a SolrService per thread, so clear any boot-time instance
  # and let later calls rebuild it with the updated connection options.
  ActiveFedora::SolrService.reset!
end
