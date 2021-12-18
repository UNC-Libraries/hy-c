# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RangeLimitCatalogSearchBuilder do
  let(:context) { double }
  let(:builder) { described_class.new(context).with(blacklight_params) }
  let(:solr_params) { Blacklight::Solr::Request.new }

  context "with a user query from the regular search" do
    let(:blacklight_params) { { q: user_query, search_field: 'all_fields' } }
    let(:user_query) { "find me" }

    subject { builder.show_works_or_works_that_contain_files(solr_params) }

    context "with a user query" do
      it "creates a valid solr join for works and files" do
        subject
        expect(solr_params[:user_query]).to eq user_query
        expect(solr_params[:q]).to eq "{!lucene}_query_:\"{!dismax v=$user_query}\" _query_:\"{!join from=id to=file_set_ids_ssim}{!dismax v=$user_query}\""
      end
    end
  end
end
