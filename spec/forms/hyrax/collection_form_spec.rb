# [hyc-override] Tests removal of :based_near (location) from form
require 'rails_helper'
# Load the override being tested
require Rails.root.join('app/overrides/forms/collection_form_override.rb')

RSpec.describe Hyrax::Forms::CollectionForm do
  describe '#terms' do
    subject { described_class.terms }

    it do
      is_expected.to eq [:resource_type,
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

  let(:collection) { Collection.new }
  let(:repository) { double }
  let(:form) { described_class.new(collection, nil, repository) }

  describe '#secondary_terms' do
    subject { form.secondary_terms }

    it do
      is_expected.to eq [
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

  describe '.build_permitted_params' do
    subject { described_class.build_permitted_params }

    it do
      is_expected.to eq [{ resource_type: [] },
                         { title: [] },
                         { creator: [] },
                         { contributor: [] },
                         :description,
                         { keyword: [] },
                         { license: [] },
                         { publisher: [] },
                         :date_created,
                         { subject: [] },
                         { language: [] },
                         :representative_id,
                         :thumbnail_id,
                         { identifier: [] },
                         { related_url: [] },
                         :visibility,
                         :collection_type_gid,
                         { permissions_attributes: [:type, :name, :access, :id, :_destroy] }]
    end
  end
end
