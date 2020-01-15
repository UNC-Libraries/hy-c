require 'rails_helper'

RSpec.describe HyraxHelper do
  describe '#language_links' do
    context 'with valid options' do
      let(:options) { {value: ['http://id.loc.gov/vocabulary/iso639-2/eng']} }

      it 'returns a link to a language search' do
        expect(helper.language_links(options)).to eq '<a href="/catalog?f%5Blanguage_sim%5D%5B%5D=http%3A%2F%2Fid.loc.gov%2Fvocabulary%2Fiso639-2%2Feng">English</a>'
      end
    end

    context 'with invalid options' do
      let(:invalid_options) { {value: ['invalid']} }

      it 'returns nil if language key is not found' do
        expect(helper.language_links(invalid_options)).to eq nil
      end
    end
  end

  describe '#language_links_facets' do
    context 'with valid options' do
      let(:options) { 'http://id.loc.gov/vocabulary/iso639-2/eng' }

      it 'returns a link to a language search' do
        expect(helper.language_links_facets(options)).to eq 'English'
      end
    end

    context 'with invalid options' do
      let(:invalid_options) { 'invalid' }

      it 'returns nil if language key is not found' do
        expect(helper.language_links_facets(invalid_options)).to eq invalid_options
      end
    end
  end

  describe '#redirect_lookup' do
    cached_redirect_file_path = ENV['REDIRECT_FILE_PATH']
    tempfile = Tempfile.new('redirect_uuids.csv', 'spec/fixtures/')
    let(:article) { Article.create(title: ['new article'], visibility: 'open') }

    before do
      ENV['REDIRECT_FILE_PATH'] = 'spec/fixtures/redirect_uuids.csv'
      File.open(ENV['REDIRECT_FILE_PATH'], 'w') do |f|
        f.puts 'uuid,new_path'
        f.puts "02fc897a-12b6-4b81-91e4-b5e29cb683a6,articles/#{article.id}"
      end
    end

    after do
      tempfile.unlink
      ENV['REDIRECT_FILE_PATH'] = cached_redirect_file_path
    end

    it 'returns redirect mapping' do
      expect(helper.redirect_lookup('uuid', '02fc897a-12b6-4b81-91e4-b5e29cb683a6').to_h).to include('uuid' => '02fc897a-12b6-4b81-91e4-b5e29cb683a6', 'new_path' => "articles/#{article.id}")
      expect(helper.redirect_lookup('new_path', "articles/#{article.id}").to_h).to include('uuid' => '02fc897a-12b6-4b81-91e4-b5e29cb683a6', 'new_path' => "articles/#{article.id}")
    end
  end
end

{"title"=>["Test General work"], "description"=>"a description", "keyword"=>["Test Default Keyword"], "license"=>["http://creativecommons.org/licenses/by/3.0/us/"], "rights_statement"=>"http://rightsstatements.org/vocab/InC/1.0/", "publisher"=>["UNC Press"], "subject"=>["test"], "language"=>["http://id.loc.gov/vocabulary/iso639-2/eng"], "identifier"=>["an identifier"], "related_url"=>["something.com"], "visibility"=>"open", "admin_set_id"=>"f0a17d9c-8b83-47ec-9c48-07b357c8f91c", "language_label"=>["English"], "license_label"=>["Attribution 3.0 United States"], "rights_statement_label"=>"In Copyright", "resource_type"=>["Other"], "admin_note"=>nil, "bibliographic_citation"=>["a citation"], "abstract"=>["an abstract"], "academic_concentration"=>["Clinical Nutrition"], "access"=>"some access", "alternative_title"=>["another title"], "award"=>"Honors", "conference_name"=>["a conference"], "copyright_date"=>["2018"], "date_captured"=>nil, "date_issued"=>["2018-10-03"], "date_other"=>["2018-10-03"], "dcmi_type"=>["http://purl.org/dc/dcmitype/Text"], "degree"=>"Bachelor of Science", "degree_granting_institution"=>"UNC", "digital_collection"=>["my collection"], "doi"=>"some-doi", "edition"=>"Preprint", "extent"=>["some extent"], "funder"=>["some funder"], "graduation_year"=>"2018", "isbn"=>["some isbn"], "issn"=>["some issn"], "journal_issue"=>"1", "journal_title"=>"a journal", "journal_volume"=>"2", "kind_of_data"=>"Text", "last_modified_date"=>"2018-10-03", "medium"=>["a medium"], "methodology"=>"My methodology", "note"=>["a note"], "page_start"=>"30", "page_end"=>"32", "peer_review_status"=>"Yes", "place_of_publication"=>["UNC"], "rights_holder"=>["an author"], "series"=>["a series"], "sponsor"=>["a sponsor"], "table_of_contents"=>["contents"], "use"=>["some use"], "deposit_agreement"=>["admin accepted the deposit agreement on 2020-01-15 17:40:23 +0000"], "based_near_attributes"=>{"0"=>{"id"=>"http://sws.geonames.org/4460162/", "_destroy"=>"", "index"=>1}}, "advisors_attributes"=>{"0"=>{"index"=>1, "name"=>"advisor", "affiliation"=>"Department of Biology", "orcid"=>"advisor orcid", "other_affiliation"=>"UNC"}, "1"=>{"index"=>2, "name"=>"", "affiliation"=>"", "orcid"=>"", "other_affiliation"=>""}}, "arrangers_attributes"=>{"0"=>{"index"=>1, "name"=>"arranger", "affiliation"=>"Department of Biology", "orcid"=>"arranger orcid", "other_affiliation"=>"UNC"}, "1"=>{"index"=>2, "name"=>"", "affiliation"=>"", "orcid"=>"", "other_affiliation"=>""}}, "composers_attributes"=>{"0"=>{"index"=>1, "name"=>"composer", "affiliation"=>"Department of Biology", "orcid"=>"composer orcid", "other_affiliation"=>"UNC"}, "1"=>{"index"=>2, "name"=>"", "affiliation"=>"", "orcid"=>"", "other_affiliation"=>""}}, "contributors_attributes"=>{"0"=>{"index"=>1, "name"=>"contributor", "affiliation"=>"Department of Biology", "orcid"=>"contributor orcid", "other_affiliation"=>"UNC"}, "1"=>{"index"=>2, "name"=>"", "affiliation"=>"", "orcid"=>"", "other_affiliation"=>""}}, "creators_attributes"=>{"0"=>{"name"=>"Test Default Creator", "index"=>1, "affiliation"=>"Department of Biology", "orcid"=>"http://orcid.org/creator", "other_affiliation"=>"UNC"}, "1"=>{"name"=>"", "index"=>2, "affiliation"=>"", "orcid"=>"", "other_affiliation"=>""}}, "project_directors_attributes"=>{"0"=>{"index"=>1, "name"=>"project director", "affiliation"=>"Department of Biology", "orcid"=>"project director orcid", "other_affiliation"=>"UNC"}, "1"=>{"index"=>2, "name"=>"", "affiliation"=>"", "orcid"=>"", "other_affiliation"=>""}}, "researchers_attributes"=>{"0"=>{"index"=>1, "name"=>"researcher", "affiliation"=>"Department of Biology", "orcid"=>"researcher orcid", "other_affiliation"=>"UNC"}, "1"=>{"index"=>2, "name"=>"", "affiliation"=>"", "orcid"=>"", "other_affiliation"=>""}}, "reviewers_attributes"=>{"0"=>{"index"=>1, "name"=>"reviewer", "affiliation"=>"Department of Biology", "orcid"=>"reviewer orcid", "other_affiliation"=>"UNC"}, "1"=>{"index"=>2, "name"=>"", "affiliation"=>"", "orcid"=>"", "other_affiliation"=>""}}, "translators_attributes"=>{"0"=>{"index"=>1, "name"=>"translator", "affiliation"=>"Department of Biology", "orcid"=>"translator orcid", "other_affiliation"=>"UNC"}, "1"=>{"index"=>2, "name"=>"", "affiliation"=>"", "orcid"=>"", "other_affiliation"=>""}}}
