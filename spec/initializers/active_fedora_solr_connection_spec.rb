# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ActiveFedora Solr connection initializer' do
  around do |example|
    ActiveFedora::SolrService.reset!
    example.run
    ActiveFedora::SolrService.reset!
  end

  it 'adds the persistent adapter and timeout options to ActiveFedora solr config' do
    expect(ActiveFedora.solr_config).to include(
      adapter: :net_http_persistent,
      open_timeout: 2,
      timeout: 5
    )
  end

  it 'builds new SolrService instances with the persistent adapter settings' do
    expect(ActiveFedora::SolrService.instance.options).to include(
      adapter: :net_http_persistent,
      open_timeout: 2,
      timeout: 5
    )
  end
end
