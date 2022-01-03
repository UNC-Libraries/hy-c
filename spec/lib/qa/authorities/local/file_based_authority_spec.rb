require 'rails_helper'

RSpec.describe Qa::Authorities::Local::FileBasedAuthority do
  let(:licenses) { Qa::Authorities::Local.subauthority_for("licenses") }

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
      let(:expected) { [] }
      it "returns no results" do
        expect(licenses.search("")).to eq(expected)
      end
    end

    context "with at least one matching entry" do
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
        expect(licenses.search("NonCommercial")).to eq(expected)
      end
      it "is case insensitive" do
        expect(licenses.search("NonCoMMercial")).to eq(expected)
      end
    end

    context "with no matching entries" do
      let(:expected) { [] }
      it "returns an empty array" do
        expect(licenses.search("penguins")).to eq(expected)
      end
    end
  end

  describe "#find" do
    context "with https in an identifier" do
      it "returns the full term record" do
        record = licenses.find("https://creativecommons.org/licenses/by/3.0/us/")
        expect(record).to be_a HashWithIndifferentAccess
        expect(record).to eq('id' => "http://creativecommons.org/licenses/by/3.0/us/", 'term' => "Attribution 3.0 United States", 'active' => 'data')
      end
    end
    context "source is a list" do
      it "has indifferent access" do
        record = licenses.find("http://creativecommons.org/licenses/by/3.0/us/")
        expect(record).to be_a HashWithIndifferentAccess
      end
    end
    context "term does not exist" do
      let(:id) { "NonID" }
      let(:expected) { {} }
      it "returns an empty hash" do
        expect(licenses.find(id)).to eq(expected)
      end
    end
    context "on a sub-authority" do
      it "returns the full term record" do
        record = licenses.find("http://creativecommons.org/licenses/by/3.0/us/")
        expect(record).to be_a HashWithIndifferentAccess
        expect(record).to eq('id' => "http://creativecommons.org/licenses/by/3.0/us/", 'term' => "Attribution 3.0 United States", 'active' => 'data')
      end
    end
  end
end
