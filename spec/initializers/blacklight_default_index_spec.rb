# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Blacklight default index initializer' do
  it 'uses the pooled repository with a persistent connection adapter' do
    connection = Blacklight.default_index.connection
    faraday = connection.instance_variable_get(:@connection)

    expect(Blacklight.default_index).to be_a(Hyc::PooledSolrRepository)
    expect(faraday.builder.adapter.klass).to eq(Faraday::Adapter::NetHttpPersistent)
  end
end
