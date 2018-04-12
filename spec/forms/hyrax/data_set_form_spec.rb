# Generated via
#  `rails generate hyrax:work DataSet`
require 'rails_helper'

RSpec.describe Hyrax::DataSetForm do
  let(:work) { DataSet.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe "#required_fields" do
    subject { form.required_fields }

    it { is_expected.to match_array [:title, :creator, :rights_statement] }
  end

  describe "#primary_terms" do
    subject { form.primary_terms }

    it { is_expected.to match_array [:title, :creator, :rights_statement] }
  end

  describe "#secondary_terms" do
    subject { form.secondary_terms }

    it { is_expected.to match_array [:abstract, :access, :affiliation, :contributor,
                                     :copyright_date, :date_created, :date_issued, :doi, :extent, :funder,
                                     :genre, :geographic_subject, :last_date_modified, :identifier,:license,
                                     :orcid, :other_affiliation, :source, :subject, :project_director,
                                     :researcher, :rights_holder, :sponsor, :use,
                                     :language, :keyword, :related_url, :resource_type, :description] }
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
          affiliation: ['library'],
          contributor: ['dean'],
          copyright_date: '2017-12-25',
          date_created: '2017-04-02', # single-valued
          date_issued: '2018-01-08',
          doi: '12345',
          extent: ['1993'],
          funder: ['dean'],
          genre: ['science'],
          geographic_subject: ['California'],
          last_date_modified: '2018-01-23',
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
      expect(subject['access']).to eq 'public'
      expect(subject['affiliation']).to eq ['library']
      expect(subject['copyright_date']).to eq '2017-12-25'
      expect(subject['date_created']).to eq ['2017-04-02']
      expect(subject['date_issued']).to eq '2018-01-08'
      expect(subject['doi']).to eq '12345'
      expect(subject['extent']).to eq ['1993']
      expect(subject['funder']).to eq ['dean']
      expect(subject['genre']).to eq ['science']
      expect(subject['geographic_subject']).to eq ['California']
      expect(subject['last_date_modified']).to eq '2018-01-23'
      expect(subject['orcid']).to eq ['12345']
      expect(subject['other_affiliation']).to eq ['duke']
      expect(subject['project_director']).to eq ['dean']
      expect(subject['researcher']).to eq ['carmen']
      expect(subject['rights_holder']).to eq ['dean']
      expect(subject['sponsor']).to eq ['david']
      expect(subject['use']).to eq ['a usage']
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
