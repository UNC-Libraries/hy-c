# Generated via
#  `rails generate hyrax:work DataSet`
require 'rails_helper'

RSpec.describe Hyrax::DataSetForm do
  let(:work) { DataSet.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe "#required_fields" do
    subject { form.required_fields }

    it { is_expected.to match_array [:title, :creator, :date_issued, :abstract, :kind_of_data, :resource_type] }
  end

  describe "#primary_terms" do
    subject { form.primary_terms }

    it { is_expected.to match_array [:title, :creator, :date_issued, :abstract, :kind_of_data, :resource_type] }
  end

  describe "#secondary_terms" do
    subject { form.secondary_terms }

    it { is_expected.to match_array [:affiliation, :affiliation_label, :dcmi_type, :doi, :extent,
                                     :funder, :geographic_subject, :last_modified_date, :project_director, :researcher,
                                     :rights_holder, :sponsor, :language, :keyword, :related_url, :description,
                                     :license, :contributor, :date_created, :subject, :orcid, :other_affiliation,
                                     :rights_statement, :language_label, :license_label, :rights_statement_label] }
  end
  
  describe "#admin_only_terms" do
    subject { form.admin_only_terms }

    it { is_expected.to match_array [:dcmi_type] }
  end
  
  describe 'default value set' do
    subject { form }
    it "dcmi type must have default values" do
      expect(form.model['dcmi_type']).to eq ['http://purl.org/dc/dcmitype/Dataset'] 
    end
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
          affiliation: ['School of Medicine', 'Carolina Center for Genome Sciences'],
          contributor: ['dean'],
          date_created: '2017-04-02', # single-valued
          date_issued: '2018-01-08',
          dcmi_type: ['type'],
          doi: '12345',
          extent: ['1993'],
          funder: ['dean'],
          geographic_subject: ['California'],
          kind_of_data: 'some data',
          last_modified_date: '2018-01-23',
          language: ['http://id.loc.gov/vocabulary/iso639-2/eng'],
          license: 'http://creativecommons.org/licenses/by/3.0/us/',
          orcid: ['an orcid'],
          other_affiliation: ['another affiliation'],
          project_director: ['dean'],
          researcher: ['carmen'],
          rights_holder: ['dean'],
          rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/',
          sponsor: ['david'],
          use: ['a usage'],
          language_label: [],
          license_label: [],
          rights_statement_label: []
      )
    end

    subject { described_class.model_attributes(params) }

    it "permits parameters" do
      expect(subject['title']).to eq ['data set name']
      expect(subject['visibility']).to eq 'open'
      expect(subject['keyword']).to eq ['data set']
      expect(subject['member_of_collection_ids']).to eq ['123456', 'abcdef']
      expect(subject['abstract']).to eq ['an abstract']
      expect(subject['affiliation']).to eq ['School of Medicine', 'Carolina Center for Genome Sciences']
      expect(subject['affiliation_label']).to eq ['School of Medicine', 'Carolina Center for Genome Sciences']
      expect(subject['date_created']).to eq '2017-04-02'
      expect(subject['date_issued']).to eq '2018-01-08'
      expect(subject['doi']).to eq '12345'
      expect(subject['extent']).to eq ['1993']
      expect(subject['funder']).to eq ['dean']
      expect(subject['dcmi_type']).to eq ['type']
      expect(subject['geographic_subject']).to eq ['California']
      expect(subject['kind_of_data']).to eq 'some data'
      expect(subject['last_modified_date']).to eq '2018-01-23'
      expect(subject['language']).to eq ['http://id.loc.gov/vocabulary/iso639-2/eng']
      expect(subject['license']).to eq ['http://creativecommons.org/licenses/by/3.0/us/']
      expect(subject['orcid']).to eq ['an orcid']
      expect(subject['other_affiliation']).to eq ['another affiliation']
      expect(subject['project_director']).to eq ['dean']
      expect(subject['researcher']).to eq ['carmen']
      expect(subject['rights_holder']).to eq ['dean']
      expect(subject['sponsor']).to eq ['david']
      expect(subject['language_label']).to eq ['English']
      expect(subject['license_label']).to eq ['Attribution 3.0 United States']
      expect(subject['rights_statement_label']).to eq ['In Copyright']
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
