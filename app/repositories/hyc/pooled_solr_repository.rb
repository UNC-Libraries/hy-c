# frozen_string_literal: true

require 'faraday/net_http_persistent'
require 'faraday/retry'

module Hyc
  class PooledSolrRepository < Blacklight::Solr::Repository
    def build_connection
      # Reuse a connection object across requests within the same passenger/puma worker
      self.class.shared_connection(connection_config)
    end

    def self.shared_connection(connection_config)
      # Ensure that each passenger processor gets its own connection rather than attempting to share
      if @shared_connection.nil? || @shared_connection_pid != Process.pid
        @shared_connection = build_raw_connection(connection_config)
        @shared_connection_pid = Process.pid
      end
      @shared_connection
    end

    def self.build_raw_connection(connection_config)
      opts = connection_config.symbolize_keys
      url = opts.fetch(:url)
      faraday = Faraday.new(
          url: url,
          request: {
            open_timeout: opts.fetch(:open_timeout, 2).to_f,
            timeout: opts.fetch(:timeout, 10).to_f
          }
        ) do |conn|
          conn.request :retry,
                      max: 1,
                      interval: 0.05,
                      interval_randomness: 0.5,
                      backoff_factor: 2,
                      retry_if: lambda { |env, _exception|
                        env.method == :post && !env.url.path.end_with?('/update')
                      },
                      exceptions: [Faraday::ConnectionFailed, Faraday::TimeoutError]
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
