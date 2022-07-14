require 'rails_helper'

RSpec.describe Hyrax::IiifManifestPresenter do
  describe '#manifest_metadata' do
    context 'work with image files' do
      subject(:presenter) { described_class.new(SolrDocument.new(work.to_solr)) }
      let(:work) { FactoryBot.create(:work_with_image_files) }
    
      it 'includes metadata' do
        expect(presenter.manifest_metadata)
          .to contain_exactly({ 'label' => 'Title', 'value' => ['Test title'] })
      end
    end

    context 'work with a person object' do
      subject(:presenter) { described_class.new(SolrDocument.new(work.to_solr)) }
      let(:work) {
        Article.new(title: ['Test article title'],
                    creators_attributes: { '0' => { name: 'Test, Person',
                                                    affiliation: 'University of North Carolina at Chapel Hill. University Libraries',
                                                    index: 1  } },
                    date_issued: '2019-10-11',
                    doi: 'doi.org/some-doi')
      }
    
      it 'includes metadata' do
        expect(presenter.manifest_metadata)
          .to contain_exactly({ 'label' => 'Title', 'value' => ['Test article title'] },
                              { 'label' => 'Creator', 'value' => ['Test, Person'] },
                              { 'label' => 'DOI', 'value' => ['doi.org/some-doi'] },
                              { 'label' => 'Date of publication', 'value' => ['October 11, 2019'] })
      end
    end
  end
end