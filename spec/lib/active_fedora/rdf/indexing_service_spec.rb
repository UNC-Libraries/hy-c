# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('app/overrides/lib/active-fedora/rdf/indexing_service_override.rb')

RSpec.describe ActiveFedora::RDF::IndexingService do
  # test that class attribute is populated from override
  let(:expected) { %w[advisors arrangers composers contributors creators project_directors
    researchers reviewers translators]
  }
  it { expect(ActiveFedora::RDF::IndexingService.person_fields).to be_equivalent_to(expected) }

  context 'creating' do
    let(:object) { ActiveFedora::Base.new }
    it 'creates label variables' do
      indexing_service = ActiveFedora::RDF::IndexingService.new(object)
      expect(indexing_service.instance_variable_get(:@person_label)).not_to be_nil
      expect(indexing_service.instance_variable_get(:@creator_label)).not_to be_nil
      expect(indexing_service.instance_variable_get(:@advisor_label)).not_to be_nil
      expect(indexing_service.instance_variable_get(:@contributor_label)).not_to be_nil
      expect(indexing_service.instance_variable_get(:@orcid_label)).not_to be_nil
      expect(indexing_service.instance_variable_get(:@affiliation_label)).not_to be_nil
      expect(indexing_service.instance_variable_get(:@other_affiliation_label)).not_to be_nil
    end
  end
end
