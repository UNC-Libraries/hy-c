# Generated via
#  `rails generate hyrax:work Multimed`
require 'rails_helper'

RSpec.describe Hyrax::MultimedForm do
  let(:work) { Multimed.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe "#required_fields" do
    subject { form.required_fields }

    it { is_expected.to match_array [:title, :creator, :abstract, :date_issued, :resource_type] }
  end

  describe "#primary_terms" do
    subject { form.primary_terms }

    it { is_expected.to match_array [:title, :creator, :abstract, :date_issued, :resource_type] }
  end

  describe "#secondary_terms" do
    subject { form.secondary_terms }

    it { is_expected.to match_array [:based_near, :dcmi_type, :digital_collection, :doi, :extent, :keyword,
                                     :language, :license, :medium, :note, :rights_statement, :subject, :language_label,
                                     :license_label, :rights_statement_label, :deposit_agreement, :agreement] }
  end
  
  describe "#admin_only_terms" do
    subject { form.admin_only_terms }

    it { is_expected.to match_array [:dcmi_type, :access, :digital_collection, :doi, :medium] }
  end

  describe 'default value set' do
    subject { form }
    it "rights statement must have a default value" do
      expect(form.model['rights_statement']).to eq 'http://rightsstatements.org/vocab/InC/1.0/'
    end

    it "language must have default values" do
      expect(form.model['language']).to eq ['http://id.loc.gov/vocabulary/iso639-2/eng']
    end
  end

  describe ".model_attributes" do
    let(:params) do
      ActionController::Parameters.new(
          title: 'multimed name', # single-valued
          creators_attributes: { '0' => { name: 'creator',
                                          orcid: 'creator orcid',
                                          affiliation: 'Carolina Center for Genome Sciences',
                                          other_affiliation: 'another affiliation'} },
          date_issued: '2018-01-09', # single-valued
          subject: ['a subject'],
          language: ['http://id.loc.gov/vocabulary/iso639-2/eng'],
          based_near: ['Italy'],
          note: ['a note'],
          orcid: ['an orcid'],
          medium: ['a medium'],
          resource_type: ['a type'],
          license: 'http://creativecommons.org/licenses/by/3.0/us/', # single-valued
          rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/', # single-valued
          abstract: ['an abstract'],
          dcmi_type: ['http://purl.org/dc/dcmitype/InteractiveResource'],
          digital_collection: ['my collection'],
          doi: '12345',
          extent: ['1999'],
          keyword: ['multimed'],
          language_label: [],
          license_label: [],
          rights_statement_label: ''
      )
    end

    subject { described_class.model_attributes(params) }

    it "permits parameters" do
      expect(subject['title']).to eq ['multimed name']
      expect(subject['subject']).to eq ['a subject']
      expect(subject['language']).to eq ['http://id.loc.gov/vocabulary/iso639-2/eng']
      expect(subject['based_near']).to eq ['Italy']
      expect(subject['resource_type']).to eq ['a type']
      expect(subject['license']).to eq ['http://creativecommons.org/licenses/by/3.0/us/']
      expect(subject['rights_statement']).to eq 'http://rightsstatements.org/vocab/InC/1.0/'
      expect(subject['note']).to eq ['a note']
      expect(subject['medium']).to eq ['a medium']
      expect(subject['keyword']).to eq ['multimed']
      expect(subject['abstract']).to eq ['an abstract']
      expect(subject['date_issued']).to eq '2018-01-09'
      expect(subject['doi']).to eq '12345'
      expect(subject['extent']).to eq ['1999']
      expect(subject['dcmi_type']).to eq ['http://purl.org/dc/dcmitype/InteractiveResource']
      expect(subject['digital_collection']).to eq ['my collection']
      expect(subject['language_label']).to eq ['English']
      expect(subject['license_label']).to eq ['Attribution 3.0 United States']
      expect(subject['rights_statement_label']).to eq 'In Copyright'
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
