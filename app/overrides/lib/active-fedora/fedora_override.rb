# frozen_string_literal: true
# https://github.com/samvera/active_fedora/blob/v14.0.1/lib/active_fedora/fedora.rb
ActiveFedora::Fedora.class_eval do
  def authorized_connection
    options = {}
    options[:ssl] = ssl_options if ssl_options
    options[:request] = request_options if request_options
    Faraday.new(host, options) do |conn|
      conn.response :encoding # use Faraday::Encoding middleware
      conn.adapter Faraday.default_adapter # net/http
      # [hyc-override] Setting timeout to 5 minutes to allow for deposit of large files (default: 60)
      conn.options.timeout = 60 * 5
      if Gem::Version.new(Faraday::VERSION) < Gem::Version.new('2')
        conn.request :basic_auth, user, password
      else
        conn.request :authorization, :basic, user, password
      end
    end
  end
end