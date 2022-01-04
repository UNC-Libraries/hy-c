require 'rails_helper'

RSpec.describe Qa::Authorities::Local::FileBasedAuthority do
  let(:licenses) { Qa::Authorities::Local.subauthority_for("licenses") }
  # TODO: Add more example file based authorities to make sure this isn't only relevant for licenses.
  # We can't be quite as agnostic as the original test:
  # See https://github.com/samvera/questioning_authority/blob/eafe9fe652d1a7efd37e0d7f2737b2d64876c601/spec/lib/authorities/local/file_based_authority_spec.rb

  describe "#all" do
    it "returns an array of hashes" do
      expect(licenses.all).to be_instance_of(Array)
      expect(licenses.all.first).to be_instance_of(HashWithIndifferentAccess)
    end
    it "has the expected keys in those hashes" do
      expect(licenses.all.first.keys).to match_array(['id', 'label', 'active'])
    end
  end

  describe "#search" do
    context "with an empty query string" do
      let(:term) { "" }
      let(:expected) { [] }
      it "returns no results" do
        results = licenses.search(term)
        expect(results).to eq(expected)
      end
    end

    context "with at least one matching entry" do
      let(:term) { 'NonCommercial' }
      let(:expected) do
        [{"id"=>"http://creativecommons.org/licenses/by-nc/3.0/us/",
          "label"=>"Attribution-NonCommercial 3.0 United States",
          "active"=>"all"},
         {"id"=>"http://creativecommons.org/licenses/by-nc/4.0/",
          "label"=>"Attribution-NonCommercial 4.0 International",
          "active"=>"all"},
         {"id"=>"http://creativecommons.org/licenses/by-nc-nd/3.0/us/",
          "label"=>"Attribution-NonCommercial-NoDerivs 3.0 United States",
          "active"=>"all"},
         {"id"=>"http://creativecommons.org/licenses/by-nc-sa/3.0/us/",
          "label"=>"Attribution-NonCommercial-ShareAlike 3.0 United States",
          "active"=>"all"}]
      end
      it "returns only entries matching the query term" do
        results = licenses.search(term)
        expect(results).to eq(expected)
      end
      context "with mismatched capitalization" do
        let(:term) { 'NonCoMMercial' }
        it "is case insensitive" do
          results = licenses.search(term)
          expect(results).to eq(expected)
        end
      end
    end
    context "with no matching entries" do
      let(:term) { 'penguins' }
      let(:expected) { [] }
      it "returns an empty array" do
        results = licenses.search(term)
        expect(results).to eq(expected)
      end
    end
  end

  describe "#find" do
    context "with results" do
      let(:https_id) { 'https://creativecommons.org/licenses/by/3.0/us/' }
      let(:id) { 'http://creativecommons.org/licenses/by/3.0/us/' }

      let(:expected) { { 'id' => id, 'term' => "Attribution 3.0 United States", 'active' => 'data' } }

      it "returns the full term record" do
        record = licenses.find(id)
        expect(record).to be_a HashWithIndifferentAccess
        expect(record).to eq(expected)
      end
      context "with https in an identifier" do
        it "returns the full term record" do
          record = licenses.find(https_id)
          expect(record).to be_a HashWithIndifferentAccess
          expect(record).to eq(expected)
        end
      end
    end
    context "term does not exist" do
      let(:id) { "NonID" }
      let(:expected) { {} }

      it "returns an empty hash" do
        record = licenses.find(id)
        expect(record).to eq(expected)
      end
      context "with mismatched capitalization" do
        let(:id) { 'http://CreativeCommons.org/licenses/by/3.0/us/' }

        it "is case sensitive" do
          record = licenses.find(id)
          expect(record).to eq(expected)
        end
      end
    end
  end
end
