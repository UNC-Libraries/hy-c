# Generated via
#  `rails generate hyrax:work General`
require 'rails_helper'

RSpec.describe Hyrax::GeneralPresenter do
  let(:solr_document) { SolrDocument.new(attributes) }
  let(:request) { double(host: 'example.org') }
  let(:user_key) { 'a_user_key' }

  let(:attributes) do
    { "id" => '888888',
      "title_tesim" => ['foo'],
      "human_readable_type_tesim" => ["Article"],
      "has_model_ssim" => ["Article"],
      "depositor_tesim" => user_key,
      "abstract_tesim" => ['an abstract'],
      "academic_concentration_tesim" => ['a concentration'],
      "access_tesim" => 'public',
      "advisor_display_tesim" => ['an advisor'],
      "alternative_title_tesim" => ['some title'],
      "arranger_display_tesim" => ['an arranger'],
      "award_tesim" => ['an award'],
      "bibliographic_citation_tesim" => ['a citation'],
      "composer_display_tesim" => ['a composer'],
      "conference_name_tesim" => ['a conference'],
      "copyright_date_tesim" => '2017-01-22',
      "creator_display_tesim" => ['a creator'],
      "contributor_display_tesim" => ['a contributor'],
      "date_issued_tesim" => '2017-01-22',
      "date_other_tesim" => ['2017-01-22'],
      "dcmi_type_tesim" => ['science fiction'],
      "degree_tesim" => 'a degree',
      "degree_granting_institution_tesim" => 'unc',
      "digital_collection_tesim" => ['a collection'],
      "doi_tesim" => '12345',
      "edition_tesim" => 'new edition',
      "extent_tesim" => ['1993'],
      "funder_tesim" => ['dean'],
      "geographic_subject_tesim" => ['California'],
      "graduation_year_tesim" => '2018',
      "isbn_tesim" => ['123456'],
      "issn_tesim" => ['12345'],
      "journal_issue_tesim" => '27',
      "journal_title_tesim" => 'Journal Title',
      "journal_volume_tesim" => '4',
      "kind_of_data_tesim" => ['data type'],
      "last_modified_date_tesim" => 'hi',
      "medium_tesim" => ['a medium'],
      "note_tesim" => ['a note'],
      "page_end_tesim" => '11',
      "page_start_tesim" => '8',
      "peer_review_status_tesim" => 'in review',
      "place_of_publication_tesim" => ['durham'],
      "project_director_display_tesim" => ['a director'],
      "publisher_version_tesim" => ['a version'],
      "researcher_display_tesim" => ['a researcher'],
      "reviewer_display_tesim" => ['a reviewer'],
      "rights_holder_tesim" => ['rights holder'],
      "series_tesim" => ['a series'],
      "sponsor_tesim" => ['a sponsor'],
      "table_of_contents_tesim" => ['contents of yon table'],
      "translator_display_tesim" => ['dean'],
      "use_tesim" => ['a use'],
      "language_label_tesim" => ['language'],
      "license_label_tesim" => ['license'],
      "rights_statement_label_tesim" => 'rights'
    }
  end

  let(:ability) { nil }
  let(:presenter) { described_class.new(solr_document, ability, request) }

  subject { described_class.new(double, double) }

  it { is_expected.to delegate_method(:to_s).to(:solr_document) }
  it { is_expected.to delegate_method(:human_readable_type).to(:solr_document) }
  it { is_expected.to delegate_method(:creator_display).to(:solr_document) }
  it { is_expected.to delegate_method(:contributor_display).to(:solr_document) }
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

  it { is_expected.to delegate_method(:abstract).to(:solr_document) }
  it { is_expected.to delegate_method(:academic_concentration).to(:solr_document) }
  it { is_expected.to delegate_method(:access).to(:solr_document) }
  it { is_expected.to delegate_method(:advisor_display).to(:solr_document) }
  it { is_expected.to delegate_method(:alternative_title).to(:solr_document) }
  it { is_expected.to delegate_method(:arranger_display).to(:solr_document) }
  it { is_expected.to delegate_method(:award).to(:solr_document) }
  it { is_expected.to delegate_method(:bibliographic_citation).to(:solr_document) }
  it { is_expected.to delegate_method(:composer_display).to(:solr_document) }
  it { is_expected.to delegate_method(:copyright_date).to(:solr_document) }
  it { is_expected.to delegate_method(:conference_name).to(:solr_document) }
  it { is_expected.to delegate_method(:date_issued).to(:solr_document) }
  it { is_expected.to delegate_method(:date_other).to(:solr_document) }
  it { is_expected.to delegate_method(:dcmi_type).to(:solr_document) }
  it { is_expected.to delegate_method(:degree).to(:solr_document) }
  it { is_expected.to delegate_method(:degree_granting_institution).to(:solr_document) }
  it { is_expected.to delegate_method(:digital_collection).to(:solr_document) }
  it { is_expected.to delegate_method(:doi).to(:solr_document) }
  it { is_expected.to delegate_method(:edition).to(:solr_document) }
  it { is_expected.to delegate_method(:extent).to(:solr_document) }
  it { is_expected.to delegate_method(:funder).to(:solr_document) }
  it { is_expected.to delegate_method(:geographic_subject).to(:solr_document) }
  it { is_expected.to delegate_method(:graduation_year).to(:solr_document) }
  it { is_expected.to delegate_method(:isbn).to(:solr_document) }
  it { is_expected.to delegate_method(:issn).to(:solr_document) }
  it { is_expected.to delegate_method(:journal_issue).to(:solr_document) }
  it { is_expected.to delegate_method(:journal_title).to(:solr_document) }
  it { is_expected.to delegate_method(:journal_volume).to(:solr_document) }
  it { is_expected.to delegate_method(:kind_of_data).to(:solr_document) }
  it { is_expected.to delegate_method(:last_modified_date).to(:solr_document) }
  it { is_expected.to delegate_method(:medium).to(:solr_document) }
  it { is_expected.to delegate_method(:note).to(:solr_document) }
  it { is_expected.to delegate_method(:page_end).to(:solr_document) }
  it { is_expected.to delegate_method(:page_start).to(:solr_document) }
  it { is_expected.to delegate_method(:peer_review_status).to(:solr_document) }
  it { is_expected.to delegate_method(:place_of_publication).to(:solr_document) }
  it { is_expected.to delegate_method(:project_director_display).to(:solr_document) }
  it { is_expected.to delegate_method(:publisher_version).to(:solr_document) }
  it { is_expected.to delegate_method(:rights_holder).to(:solr_document) }
  it { is_expected.to delegate_method(:researcher_display).to(:solr_document) }
  it { is_expected.to delegate_method(:reviewer_display).to(:solr_document) }
  it { is_expected.to delegate_method(:series).to(:solr_document) }
  it { is_expected.to delegate_method(:sponsor).to(:solr_document) }
  it { is_expected.to delegate_method(:table_of_contents).to(:solr_document) }
  it { is_expected.to delegate_method(:translator_display).to(:solr_document) }
  it { is_expected.to delegate_method(:use).to(:solr_document) }
  it { is_expected.to delegate_method(:language_label).to(:solr_document) }
  it { is_expected.to delegate_method(:license_label).to(:solr_document) }
  it { is_expected.to delegate_method(:rights_statement_label).to(:solr_document) }

  describe "#model_name" do
    subject { presenter.model_name }

    it { is_expected.to be_kind_of ActiveModel::Name }
  end

  describe "#attribute_to_html" do
    let(:renderer) { double('renderer') }

    context 'with an existing field' do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:title, ['foo'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:title)
      end
    end

    context "with a custom abstract field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:abstract, ['an abstract'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:abstract)
      end
    end

    context "with a custom academic_concentration field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:academic_concentration, ['a concentration'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:academic_concentration)
      end
    end

    context "with a custom access field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:access, 'public', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:access)
      end
    end

    context "with a custom advisor_display field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:advisor_display, ['an advisor'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:advisor_display)
      end
    end

    context "with a custom alternative_title field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:alternative_title, ['some title'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:alternative_title)
      end
    end

    context "with a custom arranger_display field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:arranger_display, ['an arranger'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:arranger_display)
      end
    end

    context "with a custom award field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:award, ['an award'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:award)
      end
    end

    context "with a custom bibliographic_citation field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:bibliographic_citation, ['a citation'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:bibliographic_citation)
      end
    end

    context "with a custom composer_display field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:composer_display, ['a composer'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:composer_display)
      end
    end

    context "with a custom conference_name field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:conference_name, ['a conference'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:conference_name)
      end
    end

    context "with a custom copyright date field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:copyright_date, '2017-01-22', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:copyright_date)
      end
    end

    context "with a custom creator_display field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:creator_display, ['a creator'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:creator_display)
      end
    end

    context "with a custom contributor_display field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:contributor_display, ['a contributor'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:contributor_display)
      end
    end

    context "with a custom date issued field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:date_issued, '2017-01-22', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:date_issued)
      end
    end

    context "with a custom date other field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:date_other, ['2017-01-22'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:date_other)
      end
    end

    context "with a custom degree field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:degree, 'a degree', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:degree)
      end
    end

    context "with a custom degree_granting_institution field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:degree_granting_institution, 'unc', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:degree_granting_institution)
      end
    end

    context "with a custom digital_collection field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:digital_collection, ['a collection'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:digital_collection)
      end
    end

    context "with a custom doi field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:doi, '12345', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:doi)
      end
    end

    context "with a custom edition field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:edition, 'new edition', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:edition)
      end
    end

    context "with a custom extent field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:extent, ['1993'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:extent)
      end
    end

    context "with a custom funder field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:funder, ['dean'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:funder)
      end
    end

    context "with a custom dcmi_type field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:dcmi_type, ['science fiction'], {}).and_return(renderer)
      end
      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:dcmi_type)
      end
    end

    context "with a custom geographic subject field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:geographic_subject, ['California'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:geographic_subject)
      end
    end

    context "with a custom graduation_year field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:graduation_year, '2018', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:graduation_year)
      end
    end

    context "with a custom isbn field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:isbn, ['123456'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:isbn)
      end
    end

    context "with a custom issn field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:issn, ['12345'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:issn)
      end
    end

    context "with a custom journal issue field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:journal_issue, '27', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:journal_issue)
      end
    end

    context "with a custom journal title field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:journal_title, 'Journal Title', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:journal_title)
      end
    end

    context "with a custom journal volume field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:journal_volume, '4', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:journal_volume)
      end
    end

    context "with a custom kind_of_data field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:kind_of_data, ['data type'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:kind_of_data)
      end
    end

    context "with a custom last_modified_date field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:last_modified_date, 'hi', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:last_modified_date)
      end
    end

    context "with a custom medium field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:medium, ['a medium'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:medium)
      end
    end

    context "with a custom note field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:note, ['a note'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:note)
      end
    end

    context "with a custom page end field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:page_end, '11', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:page_end)
      end
    end

    context "with a custom page start field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:page_start, '8', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:page_start)
      end
    end

    context "with a custom peer review status field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:peer_review_status, 'in review', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:peer_review_status)
      end
    end

    context "with a custom place of publication field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:place_of_publication, ['durham'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:place_of_publication)
      end
    end

    context "with a custom project_director_display field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:project_director_display, ['a director'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:project_director_display)
      end
    end

    context "with a custom publisher_version field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:publisher_version, ['a version'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:publisher_version)
      end
    end

    context "with a custom researcher_display field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:researcher_display, ['a researcher'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:researcher_display)
      end
    end

    context "with a custom reviewer_display field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:reviewer_display, ['a reviewer'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:reviewer_display)
      end
    end

    context "with a custom rights holder field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:rights_holder, ['rights holder'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:rights_holder)
      end
    end

    context "with a custom series field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:series, ['a series'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:series)
      end
    end

    context "with a custom sponsor field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:sponsor, ['a sponsor'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:sponsor)
      end
    end

    context "with a custom table of contents field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:table_of_contents, ['contents of yon table'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:table_of_contents)
      end
    end

    context "with a custom translator_display field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:translator_display, ['dean'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:translator_display)
      end
    end

    context "with a custom use field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:use, ['a use'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:use)
      end
    end

    context "with a custom language label field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:language_label, ['language'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:language_label)
      end
    end

    context "with a custom license label field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:license_label, ['license'], {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:license_label)
      end
    end

    context "with a custom rights statement label field" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:rights_statement_label, 'rights', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).to receive(:render)
        presenter.attribute_to_html(:rights_statement_label)
      end
    end

    context "with a field that doesn't exist" do
      before do
        allow(Hyrax::Renderers::AttributeRenderer).to receive(:new).with(:something, 'foo', {}).and_return(renderer)
      end

      it "calls the AttributeRenderer" do
        expect(renderer).not_to receive(:render)
      end
    end
  end
end
