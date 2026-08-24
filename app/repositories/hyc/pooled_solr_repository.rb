# frozen_string_literal: true

require 'faraday/net_http_persistent'
require 'faraday/retry'

module Hyc
  class PooledSolrRepository < Blacklight::Solr::Repository
    def build_connection
      opts = connection_config.symbolize_keys
      url = opts.fetch(:url)
      faraday = Faraday.new(
          url: url,
          request: {
            open_timeout: opts.fetch(:open_timeout, 2).to_f,
            timeout: opts.fetch(:timeout, 10).to_f
          }
        ) do |conn|
            conn.request :retry, max: 2, interval: 0.05, interval_randomness: 0.5,
                        backoff_factor: 2, exceptions: [Faraday::ConnectionFailed, Faraday::TimeoutError]
            conn.response :raise_error
            conn.adapter :net_http_persistent
        end
      RSolr::Client.new(
        faraday,
        url: url
      )
    end
  end
end