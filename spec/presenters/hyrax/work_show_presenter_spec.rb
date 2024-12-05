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

  it { is_expected.to delegate_method(:doi).to(:solr_document) }

  it { is_expected.to delegate_method(:to_s).to(:solr_document) }
  it { is_expected.to delegate_method(:human_readable_type).to(:solr_document) }
  it { is_expected.to delegate_method(:date_created).to(:solr_document) }
  it { is_expected.to delegate_method(:date_modified).to(:solr_document) }
  it { is_expected.to delegate_method(:date_uploaded).to(:solr_document) }
  it { is_expected.to delegate_method(:rights_statement).to(:solr_document) }

  it { is_expected.to delegate_method(:based_near_label).to(:solr_document) }
  it { is_expected.to delegate_method(:related_url).to(:solr_document) }
  it { is_expected.to delegate_method(:depositor).to(:solr_document) }
  it { is_expected.to delegate_method(:identifier).to(:solr_document) }
  it { is_expected.to delegate_method(:resource_type).to(:solr_document) }
  it { is_expected.to delegate_method(:keyword).to(:solr_document) }
  it { is_expected.to delegate_method(:itemtype).to(:solr_document) }

  describe '#representative_presenter' do
    context 'when member_presenters raises a Hyrax::ObjectNotFoundError' do
      before do
        allow(presenter).to receive(:fetch_primary_fileset_id).and_return('file_set_id_1')
        allow(presenter).to receive(:member_presenters).and_raise(Hyrax::ObjectNotFoundError)
        allow(Hyrax.logger).to receive(:warn)
      end

      it 'logs a warning and returns nil' do
        result = presenter.representative_presenter
        expect(Hyrax.logger).to have_received(:warn).with('Unable to find representative_id file_set_id_1 for work 888888')
        expect(result).to be_nil
      end
    end
  end
end
