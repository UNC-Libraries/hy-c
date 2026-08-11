# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('app/overrides/presenters/hyrax/work_show_presenter_override.rb')

RSpec.describe Hyrax::WorkShowPresenter do
  let(:solr_document) { SolrDocument.new(attributes) }
  let(:request) { double(host: 'example.org', base_url: 'http://example.org') }
  let(:user_key) { 'a_user_key' }

  let(:attributes) do
    { 'id' => '888888',
      'title_tesim' => ['foo', 'bar'],
      'human_readable_type_tesim' => ['Article'],
      'has_model_ssim' => ['Article'],
      'date_created_tesim' => ['an unformatted date'],
      'depositor_tesim' => user_key }
  end
  let(:ability) { double Ability }
  let(:presenter) { described_class.new(solr_document, ability, request) }

  subject { described_class.new(double, double) }

  it { expect(subject.scholarly?).to be false }
end
