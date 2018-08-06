# Generated via
#  `rails generate hyrax:work DataSet`
require 'rails_helper'

RSpec.describe Hyrax::DataSetForm do
  let(:work) { DataSet.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe "#required_fields" do
    subject { form.required_fields }

    it { is_expected.to match_array [:title, :creator, :date_issued] }
  end

  describe "#primary_terms" do
    subject { form.primary_terms }

    it { is_expected.to match_array [:title, :creator, :date_issued] }
  end

  describe "#secondary_terms" do
    subject { form.secondary_terms }

    it { is_expected.to match_array [:abstract, :affiliation, :copyright_date, :doi, :extent, :funder,
                                     :geographic_subject, :kind_of_data, :last_modified_date, :project_director,
                                     :researcher, :rights_holder, :sponsor, :language, :keyword, :related_url,
                                     :resource_type, :description, :license, :contributor, :date_created,
                                     :subject] }
  end
  
  describe "#suppressed_terms" do
    subject { form.suppressed_terms }

    it { is_expected.to match_array [:dcmi_type] }
  end

  describe ".model_attributes" do
    let(:params) do
      ActionController::Parameters.new(
          title: 'data set name', # single-valued
          visibility: 'open',
          representative_id: '456',
          thumbnail_id: '789',
          keyword: ['data set'],
          member_of_collection_ids: ['123456', 'abcdef'],
          abstract: ['an abstract'],
          access: 'public',
          affiliation: ['SILS'],
          contributor: ['dean'],
          copyright_date: '2017-12-25',
          date_created: '2017-04-02', # single-valued
          date_issued: '2018-01-08',
          doi: '12345',
          extent: ['1993'],
          funder: ['dean'],
          geographic_subject: ['California'],
          kind_of_data: ['some data'],
          last_modified_date: '2018-01-23',
          orcid: ['12345'],
          other_affiliation: ['duke'],
          project_director: ['dean'],
          researcher: ['carmen'],
          rights_holder: ['dean'],
          sponsor: ['david'],
          use: ['a usage']

      )
    end

    subject { described_class.model_attributes(params) }

    it "permits parameters" do
      expect(subject['title']).to eq ['data set name']
      expect(subject['visibility']).to eq 'open'
      expect(subject['keyword']).to eq ['data set']
      expect(subject['member_of_collection_ids']).to eq ['123456', 'abcdef']
      expect(subject['abstract']).to eq ['an abstract']
      expect(subject['affiliation']).to eq ['SILS']
      expect(subject['copyright_date']).to eq '2017-12-25'
      expect(subject['date_created']).to eq '2017-04-02'
      expect(subject['date_issued']).to eq '2018-01-08'
      expect(subject['doi']).to eq '12345'
      expect(subject['extent']).to eq ['1993']
      expect(subject['funder']).to eq ['dean']
      expect(subject['dcmi_type']).to eq ['http://purl.org/dc/dcmitype/Dataset']
      expect(subject['geographic_subject']).to eq ['California']
      expect(subject['kind_of_data']).to eq ['some data']
      expect(subject['last_modified_date']).to eq '2018-01-23'
      expect(subject['project_director']).to eq ['dean']
      expect(subject['researcher']).to eq ['carmen']
      expect(subject['rights_holder']).to eq ['dean']
      expect(subject['sponsor']).to eq ['david']
    end

    describe "#visibility" do
      subject { form.visibility }

      it { is_expected.to eq 'restricted' }
    end

    describe "#agreement_accepted" do
      subject { form.agreement_accepted }

      it { is_expected.to eq false }
    end

    context "on a work already saved" do
      before { allow(work).to receive(:new_record?).and_return(false) }
      it "defaults deposit agreement to true" do
        expect(form.agreement_accepted).to eq(true)
      end
    end
  end
end
