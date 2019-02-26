# Generated via
#  `rails generate hyrax:work HonorsThesis`
require 'rails_helper'

RSpec.describe Hyrax::HonorsThesisForm do
  let(:work) { HonorsThesis.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe "#required_fields" do
    subject { form.required_fields }

    it do  is_expected.to match_array [:title, :abstract, :advisor, :affiliation, :creator, :date_issued, :degree,
                                       :graduation_year]
    end
  end

  describe "#primary_terms" do
    subject { form.primary_terms }

    it do  is_expected.to match_array [:title, :abstract, :advisor, :creator, :date_issued, :degree,
                                       :graduation_year]
    end
  end

  describe "#secondary_terms" do
    subject { form.secondary_terms }

    it { is_expected.to match_array [:access, :award, :based_near, :date_created, :dcmi_type, :doi, :extent,
                                     :honors_concentration, :note, :use, :language, :license, :resource_type,
                                     :rights_statement, :subject, :keyword, :related_url, :language_label,
                                     :license_label, :rights_statement_label, :degree_granting_institution] }
  end
  
  describe "#admin_only_terms" do
    subject { form.admin_only_terms }

    it { is_expected.to match_array [:dcmi_type, :access, :award, :date_created, :degree_granting_institution,
                                     :doi, :extent, :honors_concentration, :use] }
  end
  
  describe 'default value set' do
    subject { form }
    it "dcmi type must have default values" do
      expect(form.model['dcmi_type']).to eq ['http://purl.org/dc/dcmitype/Text']
    end

    it "rights statement must have a default value" do
      expect(form.model['rights_statement']).to eq 'http://rightsstatements.org/vocab/InC/1.0/'
    end

    it "language must have default values" do
      expect(form.model['language']).to eq ['http://id.loc.gov/vocabulary/iso639-2/eng']
    end
  end

  describe '.model_attributes' do
    let(:params) do
      ActionController::Parameters.new(
          title: 'foo', # single-valued
          creators_attributes: { '0' => { name: 'creator',
                                          orcid: 'creator orcid',
                                          affiliation: 'Carolina Center for Genome Sciences',
                                          other_affiliation: 'another affiliation'} },
          keyword: ['a keyword'],
          language: ['http://id.loc.gov/vocabulary/iso639-2/eng'],
          based_near: ['California'],
          license: 'http://creativecommons.org/licenses/by/3.0/us/', # single-valued
          resource_type: ['a type'],
          rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/', # single-valued
          subject: ['a subject'],
          visibility: 'open',
          representative_id: '456',
          thumbnail_id: '789',
          member_of_collection_ids: ['123456', 'abcdef'],
          abstract: [''],
          access: 'public', # single-valued
          advisors_attributes: { '0' => { name: 'advisor',
                                          orcid: 'advisor orcid',
                                          affiliation: 'Carolina Center for Genome Sciences',
                                          other_affiliation: 'another affiliation'} },
          award: 'Honors', # single-valued
          dcmi_type: ['type'],
          degree: 'MSIS', # single-valued
          degree_granting_institution: 'UNC', # single-valued
          doi: '12345',
          extent: ['an extent'],
          graduation_year: '2017',
          honors_concentration: ['a concentration'],
          note: [''],
          use: ['a use'],
          language_label: [],
          license_label: [],
          rights_statement_label: ''
      )
    end

    subject { described_class.model_attributes(params) }

    it 'permits parameters' do
      expect(subject['title']).to eq ['foo']
      expect(subject['keyword']).to eq ['a keyword']
      expect(subject['language']).to eq ['http://id.loc.gov/vocabulary/iso639-2/eng']
      expect(subject['based_near']).to eq ['California']
      expect(subject['resource_type']).to eq ['a type']
      expect(subject['rights_statement']).to eq 'http://rightsstatements.org/vocab/InC/1.0/'
      expect(subject['subject']).to eq ['a subject']
      expect(subject['visibility']).to eq 'open'
      expect(subject['representative_id']).to eq '456'
      expect(subject['thumbnail_id']).to eq '789'
      expect(subject['member_of_collection_ids']).to eq ['123456', 'abcdef']
      expect(subject['doi']).to eq '12345'
      expect(subject['abstract']).to be_empty
      expect(subject['access']).to eq 'public'
      expect(subject['award']).to eq 'Honors'
      expect(subject['degree']).to eq 'MSIS'
      expect(subject['degree_granting_institution']).to eq 'UNC'
      expect(subject['extent']).to eq ['an extent']
      expect(subject['dcmi_type']).to eq ['type']
      expect(subject['license']).to eq ['http://creativecommons.org/licenses/by/3.0/us/']
      expect(subject['graduation_year']).to eq '2017'
      expect(subject['honors_concentration']).to eq ['a concentration']
      expect(subject['note']).to be_empty
      expect(subject['use']).to eq ['a use']
      expect(subject['language_label']).to eq ['English']
      expect(subject['license_label']).to eq ['Attribution 3.0 United States']
      expect(subject['rights_statement_label']).to eq 'In Copyright'
    end

    context '.model_attributes' do
      let(:params) do
        ActionController::Parameters.new(
            title: '',
            abstract: [''],
            keyword: [''],
            license: '',
            member_of_collection_ids: [''],
            rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/',
            on_behalf_of: 'Melissa'
        )
      end

      it 'removes blank parameters' do
        expect(subject['title']).to be_nil
        expect(subject['abstract']).to be_empty
        expect(subject['license']).to be_nil
        expect(subject['keyword']).to be_empty
        expect(subject['member_of_collection_ids']).to be_empty
        expect(subject['on_behalf_of']).to eq 'Melissa'
      end
    end
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
