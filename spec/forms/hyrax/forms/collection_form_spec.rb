# frozen_string_literal: true
# [hyc-override] Tests removal of :based_near (location) from form
# https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/spec/forms/hyrax/forms/collection_form_spec.rb
require 'rails_helper'

RSpec.describe Hyrax::Forms::CollectionForm do
  describe '.terms' do
    subject { described_class.terms }

    it do
      is_expected.to eq [:alternative_title,
                         :resource_type,
                         :title,
                         :creator,
                         :contributor,
                         :description,
                         :keyword,
                         :license,
                         :publisher,
                         :date_created,
                         :subject,
                         :language,
                         :representative_id,
                         :thumbnail_id,
                         :identifier,
                         :related_url,
                         :visibility,
                         :collection_type_gid]
    end
  end

  describe '#secondary_terms' do
    let(:collection) { Collection.new }
    let(:repository) { double }
    let(:form) { described_class.new(collection, nil, repository) }

    subject { form.secondary_terms }

    it do
      is_expected.to eq [
                          :alternative_title,
                          :creator,
                          :contributor,
                          :keyword,
                          :license,
                          :publisher,
                          :date_created,
                          :subject,
                          :language,
                          :identifier,
                          :related_url,
                          :resource_type
                        ]
    end
  end
end
