# frozen_string_literal: true
ActiveFedora::Fedora.class_eval do
  def authorized_connection
    options = {}
    options[:ssl] = ssl_options if ssl_options
    options[:request] = request_options if request_options
    Faraday.new(host, options) do |conn|
      conn.response :encoding # use Faraday::Encoding middleware
      conn.adapter Faraday.default_adapter # net/http
      conn.options.timeout = 60 * 5
      if Gem::Version.new(Faraday::VERSION) < Gem::Version.new('2')
        conn.request :basic_auth, user, password
      else
        conn.request :authorization, :basic, user, password
      end
    end
  end
end