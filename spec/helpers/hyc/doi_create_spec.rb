require 'rails_helper'

RSpec.describe Hyc::DoiCreate do
  describe '#initialize' do
    skip "Add your tests here"
  end

  describe '#doi_request' do
    skip "Add your tests here"
  end

  describe '#format_data' do
    context 'for an article' do
      let(:record) { {'title_tesim' => ['new article'],
                      'dcmi_type_tesim' => ['http://purl.org/dc/dcmitype/Text'],
                      'resource_type_tesim' => ['Article'],
                      'id' => 'd7f59f11-a35b-41cd-a7d9-77f36738b728',
                      'has_model_ssim' => 'Article'} }
      let(:work) { Article.new(title: ['new article'], date_issued: DateTime.now)}

      it 'includes a correct url' do
        result = described_class.new.format_data(record, work)
        expect(JSON.parse(result)['data']['attributes']['url']).to eq 'https://localhost:4040/concern/articles/d7f59f11-a35b-41cd-a7d9-77f36738b728'
      end
    end

    context 'for an honors thesis' do
      let(:record) { {'title_tesim' => ['new article'],
                      'dcmi_type_tesim' => ['http://purl.org/dc/dcmitype/Text'],
                      'resource_type_tesim' => ['Thesis'],
                      'id' => 'd7f59f11-a35b-41cd-a7d9-77f36738b728',
                      'has_model_ssim' => 'HonorsThesis'} }
      let(:work) { HonorsThesis.new(title: ['new thesis'], date_issued: DateTime.now)}

      it 'includes a correct url' do
        result = described_class.new.format_data(record, work)
        expect(JSON.parse(result)['data']['attributes']['url']).to eq 'https://localhost:4040/concern/honors_theses/d7f59f11-a35b-41cd-a7d9-77f36738b728'
      end
    end
  end

  describe '#create_doi' do
    skip "Add your tests here"
  end

  describe '#create_batch_doi' do
    skip "Add your tests here"
  end

  describe '#parse_field' do
    skip "Add your tests here"
  end

  describe '#parse_resource_type' do
    skip "Add your tests here"
  end

  describe '#parse_funding' do
    skip "Add your tests here"
  end

  describe '#parse_subjects' do
    skip "Add your tests here"
  end

  describe '#parse_description' do
    skip "Add your tests here"
  end

  describe '#parse_people' do
    skip "Add your tests here"
  end
end
