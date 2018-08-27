require 'rails_helper'

def new_state
  Blacklight::SearchState.new({}, CatalogController.blacklight_config)
end

RSpec.describe HyraxHelper, type: :helper do
  describe "#language_links" do
    it "maps the url to a link with a label" do
      expect(helper.language_links(
          value: ["http://id.loc.gov/vocabulary/iso639-2/eng"]
      )).to eq("<a href=\"/catalog?f%5Blanguage_sim%5D%5B%5D=http%3A%2F%2Fid.loc.gov%2Fvocabulary%2Fiso639-2%2Feng\">English</a>")
    end

    it "converts multiple languages to a sentence" do
      expect(helper.language_links(
          value: ["http://id.loc.gov/vocabulary/iso639-2/eng",
                  "http://id.loc.gov/vocabulary/iso639-2/aar",
                  "http://id.loc.gov/vocabulary/iso639-2/ady"]
      )).to eq("<a href=\"/catalog?f%5Blanguage_sim%5D%5B%5D=http%3A%2F%2Fid.loc.gov%2Fvocabulary%2Fiso639-2%2Feng\">English</a>, " \
               "<a href=\"/catalog?f%5Blanguage_sim%5D%5B%5D=http%3A%2F%2Fid.loc.gov%2Fvocabulary%2Fiso639-2%2Faar\">Afar</a>, " \
               "and <a href=\"/catalog?f%5Blanguage_sim%5D%5B%5D=http%3A%2F%2Fid.loc.gov%2Fvocabulary%2Fiso639-2%2Fady\">Adyghe |  Adygei</a>")
    end
  end

  describe "#language_links_facets" do
    it "maps the url to a link with a label" do
      expect(helper.language_links_facets(
          "http://id.loc.gov/vocabulary/iso639-2/eng"
      )).to eq("<a href=\"/catalog?f%5Blanguage_sim%5D%5B%5D=http%3A%2F%2Fid.loc.gov%2Fvocabulary%2Fiso639-2%2Feng\">English</a>")
    end
  end
end