# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Blacklight::Document::DublinCore' do
  let(:work_solr) { work.to_solr }
  let(:document) { SolrDocument.new(work_solr) }

  describe '#dublin_core_field_names' do
    let(:work) { General.new }

    it 'list of fields, including added thumbnail field' do
      expect(document.dublin_core_field_names).to eq [:contributor, :coverage, :creator, :date, :description, :format, :identifier, :language, :publisher, :relation,
          :rights, :source, :subject, :title, :type, :thumbnail]
    end
  end

  describe '#deleted?' do
    let(:work) { Article.new(id: '123456', title: ['654321']) }

    context 'with work in deposited state' do
      it 'returns false' do
        allow(document).to receive(:fetch).with('workflow_state_name_ssim', nil).and_return('deposited')
        expect(document.deleted?).to be_falsey
      end
    end

    context 'with work in withdrawn state' do
      it 'returns true' do
        allow(document).to receive(:fetch).with('workflow_state_name_ssim', nil).and_return('withdrawn')
        expect(document.deleted?).to be_truthy
      end
    end
  end

  describe '#export_as_oai_dc_xml' do
    context 'with creator people objects' do
      let(:work) { Article.new(id: '123456', title: ['654321'],
                    creators_attributes: { '0' => { name: 'User4, A',
                                                    other_affiliation: 'Oregon Health & Science University',
                                                    index: 4 },
                                           '1' => { name: 'User1, B',
                                                    affiliation: 'Carolina Center for Genome Sciences',
                                                    index: 1 },
                                           '2' => { name: 'User3, C',
                                                    index: 3 },
                                           '3' => { name: 'User0, D',
                                                    index: 2 } }
        )
      }

      it 'returns xml document with creator objects in index order' do
        xml_doc = Nokogiri::XML(document.export_as_oai_dc_xml)
        puts "Result: #{document.export_as_oai_dc_xml}"
        creators = xml_doc.xpath('//dc:creator', 'dc' => 'http://purl.org/dc/elements/1.1/').map(&:text)
        expect(creators).to eq ['User1, B', 'User0, D', 'User3, C', 'User4, A']
      end
    end

    context 'with contributor people objects' do
      let(:work) { Article.new(id: '123456', title: ['654321'],
                    translators_attributes: { '0' => { name: 'User4, A',
                                                      other_affiliation: 'Oregon Health & Science University',
                                                      index: 2 },
                                             '1' => { name: 'User1, B',
                                                      affiliation: 'Eshelman School of Pharmacy, Division of Pharmaceutical Outcomes and Policy',
                                                      index: 1 } }
        )
      }

      it 'returns xml document with contributors in index order' do
        xml_doc = Nokogiri::XML(document.export_as_oai_dc_xml)
        contributors = xml_doc.xpath('//dc:contributor', 'dc' => 'http://purl.org/dc/elements/1.1/').map(&:text)
        # No affiliation is captured under dc:contributor for people objects that map to dc:contributor
        expect(contributors).to eq ['User1, B', 'User4, A']
      end
    end

    context 'with source values' do
      let(:work) { Article.new(id: '123456', title: ['654321'],
                    journal_issue: '11',
                    journal_title: 'International Journal of Health Policy and Management',
                    journal_volume: '5'

        )
      }

      it 'returns xml document with journal fields formatted as dc:source' do
        xml_doc = Nokogiri::XML(document.export_as_oai_dc_xml)
        sources = xml_doc.xpath('//dc:source', 'dc' => 'http://purl.org/dc/elements/1.1/').map(&:text)
        expect(sources).to eq ['International Journal of Health Policy and Management, 5(11)']
      end
    end

    context 'with thumbnail' do
      let(:work) { Article.new(id: '123456', title: ['654321']) }
      before do
        work_solr['thumbnail_path_ss'] = '/downloads/123456?file=thumbnail'
      end

      it 'returns record, thumbnail and download urls as identifiers' do
        xml_doc = Nokogiri::XML(document.export_as_oai_dc_xml)
        identifiers = xml_doc.xpath('//dc:identifier', 'dc' => 'http://purl.org/dc/elements/1.1/').map(&:text)
        # Contains an identifier to the resource itself in addition to the thumb/download links
        expect(identifiers).to eq [
            "#{ENV['HYRAX_HOST']}/concern/articles/123456",
            "#{ENV['HYRAX_HOST']}/downloads/123456?file=thumbnail",
            "#{ENV['HYRAX_HOST']}/downloads/123456"]
      end
    end
  end
end
