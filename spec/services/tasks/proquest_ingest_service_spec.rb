require 'rails_helper'

RSpec.describe Tasks::ProquestIngestService do
  let(:args) { {configuration_file: 'spec/fixtures/proquest/proquest_config.yml'} }

  after do
    FileUtils.rm_rf(Dir.glob('spec/fixtures/proquest/tmp/*'))
  end

  describe '#initialize' do
    it 'sets all params' do
      service = Tasks::ProquestIngestService.new(args)

      expect(service.temp).to eq 'spec/fixtures/proquest/tmp'
      expect(service.admin_set_id).to eq AdminSet.where(title: 'default').first.id
      expect(service.depositor_onyen).to eq 'admin'
      expect(service.deposit_record_hash).to include({ title: 'Deposit by ProQuest Depositor via CDR COllector 1.0',
                                                       deposit_method: 'CDR Collector 1.0',
                                                       deposit_package_type: 'http://proquest.com',
                                                       deposit_package_subtype: nil,
                                                       deposited_by: 'admin' })
      expect(service.metadata_dir).to eq 'spec/fixtures/proquest'
    end
  end

  describe '#migrate_proquest_packages' do
    it 'ingests proquest records' do
      allow(Date).to receive(:today).and_return(Date.parse('2019-09-12'))

      expect{Tasks::ProquestIngestService.new(args).migrate_proquest_packages}.to change{ Dissertation.count }.by(7).and change{ DepositRecord.count }.by(7)

      # check embargo information
      dissertations = Dissertation.all
      dissertation1 = dissertations[-7]
      dissertation2 = dissertations[-6]
      dissertation3 = dissertations[-5]
      dissertation4 = dissertations[-4]
      dissertation5 = dissertations[-3]
      dissertation6 = dissertations[-2]
      dissertation7 = dissertations[-1]

      # first dissertation - embargo code: 3, publication year: 2019
      expect(dissertation1['depositor']).to eq 'admin'
      expect(dissertation1['title']).to match_array ['Perspective on Attachments and Ingests']
      expect(dissertation1['label']).to eq 'Perspective on Attachments and Ingests'
      expect(dissertation1['date_issued']).to eq '2019'
      expect(dissertation1['creators'][0]['name']).to match_array ['Smith, Blandy']
      expect(dissertation1['keyword']).to match_array ['Philosophy', 'attachments', 'aesthetics']
      expect(dissertation1['resource_type']).to match_array ['Dissertation']
      expect(dissertation1['abstract']).to match_array ['The purpose of this study is to test ingest of a proquest deposit object without any attachments']
      expect(dissertation1['advisors'][0]['name']).to match_array ['Advisor, John T']
      expect(dissertation1['degree']).to eq 'Doctor of Philosophy'
      expect(dissertation1['degree_granting_institution']).to eq 'University of North Carolina at Chapel Hill Graduate School'
      expect(dissertation1['dcmi_type']).to match_array ['http://purl.org/dc/dcmitype/Text']
      expect(dissertation1['graduation_year']).to eq '2019'
      expect(dissertation1.visibility).to eq 'restricted'
      expect(dissertation1.embargo_release_date).to eq (Date.today.to_datetime + 2.years)

      # second dissertation - embargo code: 2, publication year: 2019
      expect(dissertation2['date_issued']).to eq '2019'
      expect(dissertation2['graduation_year']).to eq '2019'
      expect(dissertation2['resource_type']).to match_array ['Masters Thesis']
      expect(dissertation2.visibility).to eq 'restricted'
      expect(dissertation2.embargo_release_date).to eq (Date.today.to_datetime + 1.year)

      # third dissertation - embargo code: 3, publication year: 2017
      expect(dissertation3['date_issued']).to eq '2017'
      expect(dissertation3['graduation_year']).to eq '2019'
      expect(dissertation3.visibility).to eq 'restricted'
      expect(dissertation3.embargo_release_date).to eq Date.parse('2019-12-31').to_datetime

      # fourth dissertation - embargo code: 4, publication year: 2019
      expect(dissertation4['date_issued']).to eq '2019'
      expect(dissertation4['graduation_year']).to eq '2019'
      expect(dissertation4.visibility).to eq 'restricted'
      expect(dissertation4.embargo_release_date).to eq (Date.today.to_datetime + 2.years)

      # fifth dissertation - embargo code: 0, publication year: 2018
      expect(dissertation5['date_issued']).to eq '2018'
      expect(dissertation5['graduation_year']).to eq '2019'
      expect(dissertation5.visibility).to eq 'open'
      expect(dissertation5.embargo_release_date).to be_nil

      # sixth dissertation - embargo code: 4, publication year: 2018
      expect(dissertation6['date_issued']).to eq '2018'
      expect(dissertation6['graduation_year']).to eq '2019'
      expect(dissertation6.visibility).to eq 'restricted'
      expect(dissertation6.embargo_release_date).to eq Date.parse('2020-12-31').to_datetime

      # seventh dissertation - embargo code: 2, publication year: 2018
      expect(dissertation7['date_issued']).to eq '2018'
      expect(dissertation7['graduation_year']).to eq '2019'
      expect(dissertation7.visibility).to eq 'restricted'
      expect(dissertation7.embargo_release_date).to eq Date.parse('2019-12-31').to_datetime
    end
  end

  describe '#extract_proquest_files' do
    it 'extracts files from zip' do
      expect(Tasks::ProquestIngestService.new(args).extract_proquest_files('spec/fixtures/proquest/proquest-attach0.zip'))
          .to eq 'spec/fixtures/proquest/tmp/proquest-attach0'
    end
  end

  describe '#ingest_proquest_file' do
    let(:dissertation) { Dissertation.create(title: ['new dissertation']) }
    let(:metadata) { {title: ['new dissertation file']} }
    let(:file) { 'spec/fixtures/proquest/attach_unc_1.pdf' }

    it 'saves a fileset' do
      expect{Tasks::ProquestIngestService.new(args).ingest_proquest_file(parent: dissertation, resource: metadata, f: file)}
          .to change{ FileSet.count }.by(1)
    end
  end

  describe '#proquest_metadata' do
    let(:metadata_file) { 'spec/fixtures/proquest/attach_unc_1_DATA.xml' }

    it 'parses metadata from proquest xml' do
      service = Tasks::ProquestIngestService.new(args)
      service.instance_variable_set(:@file_last_modified, Date.yesterday)
      attributes, files = service.proquest_metadata(metadata_file)
      expect(attributes).to include({'title'=>['Perspective on Attachments and Ingests'],
                                     'label'=>'Perspective on Attachments and Ingests',
                                     'depositor'=>'admin',
                                     'creators_attributes'=>{'0'=> {'name'=>'Smith, Blandy', 'affiliation'=>['Department of Philosophy']}},
                                     'date_issued'=>'2019',
                                     'abstract'=>'The purpose of this study is to test ingest of a proquest deposit object without any attachments',
                                     'advisors_attributes'=>{'0'=>{'name'=>'Advisor, John T', 'affiliation'=>nil}},
                                     'dcmi_type'=>'http://purl.org/dc/dcmitype/Text',
                                     'degree'=>'Doctor of Philosophy',
                                     'degree_granting_institution'=>'University of North Carolina at Chapel Hill Graduate School',
                                     'graduation_year'=>'2019',
                                     'language'=>['http://id.loc.gov/vocabulary/iso639-2/eng'],
                                     'rights_statement'=>'http://rightsstatements.org/vocab/InC-EDU/1.0/',
                                     'keyword'=>['aesthetics', 'attachments', 'Philosophy'],
                                     'resource_type'=>'Dissertation',
                                     'visibility'=>'restricted',
                                     'embargo_release_date'=>'2021-11-13',
                                     'visibility_during_embargo'=>'restricted',
                                     'visibility_after_embargo'=>'open'})
      expect(files).to match_array ['noattach_unc_1.pdf', 'attached1.pdf', 'attached2.txt']
    end
  end

  describe '#build_person_hash' do
    let(:people) { ['Smith, Blandy', 'Advisor, John T.'] }
    let(:affiliation) { 'Department of Philosophy' }

    it 'returns hash for creating a person object' do
      expect(Tasks::ProquestIngestService.new(args).build_person_hash(people, affiliation)).to include({'0' => {'name'=>'Smith, Blandy', 'affiliation'=>'Department of Philosophy'},
                                                                                                        '1' => {'name'=>'Advisor, John T.', 'affiliation'=>'Department of Philosophy'}})
    end
  end

  describe '#format_name' do
    let(:xml) { Nokogiri::XML('<DISS_name><DISS_surname>Smith</DISS_surname><DISS_fname>Blandy</DISS_fname><DISS_middle/><DISS_suffix/><DISS_affiliation>University of North Carolina at Chapel Hill</DISS_affiliation></DISS_name>') }

    it 'returns formatted names' do
      expect(Tasks::ProquestIngestService.new(args).format_name(xml.xpath('//DISS_name').first)).to eq 'Smith, Blandy'
    end
  end

  describe '#file_record' do
    let(:metadata) { {'title'=>['Perspective on Attachments and Ingests'],
                      'label'=>'Perspective on Attachments and Ingests',
                      'depositor'=>'admin',
                      'creators_attributes'=>{'0'=> {'name'=>'Smith, Blandy', 'affiliation'=>['Department of Philosophy']}},
                      'date_issued'=>'2019',
                      'abstract'=>'The purpose of this study is to test ingest of a proquest deposit object without any attachments',
                      'advisors_attributes'=>{'0'=>{'name'=>'Advisor, John T', 'affiliation'=>nil}},
                      'dcmi_type'=>'http://purl.org/dc/dcmitype/Text',
                      'degree'=>'Doctor of Philosophy',
                      'degree_granting_institution'=>'University of North Carolina at Chapel Hill Graduate School',
                      'graduation_year'=>'2019',
                      'language'=>['http://id.loc.gov/vocabulary/iso639-2/eng'],
                      'rights_statement'=>'http://rightsstatements.org/vocab/InC-EDU/1.0/',
                      'keyword'=>['aesthetics', 'attachments', 'Philosophy'],
                      'resource_type'=>'Dissertation',
                      'visibility'=>'restricted',
                      'embargo_release_date'=>'2021-11-13',
                      'visibility_during_embargo'=>'restricted',
                      'visibility_after_embargo'=>'open'} }

    it 'returns fileset metadata' do
      expect(Tasks::ProquestIngestService.new(args).file_record(metadata)).to include({"date_created" => nil,
                                                                                       "depositor" => "admin",
                                                                                       "embargo_release_date" => "2021-11-13",
                                                                                       "keyword" => ["aesthetics", "attachments", "Philosophy"],
                                                                                       "label" => "Perspective on Attachments and Ingests",
                                                                                       "language" => ["http://id.loc.gov/vocabulary/iso639-2/eng"],
                                                                                       "resource_type" => ["Dissertation"],
                                                                                       "rights_statement" => "http://rightsstatements.org/vocab/InC-EDU/1.0/",
                                                                                       "title" => ["Perspective on Attachments and Ingests"],
                                                                                       "visibility" => "restricted",
                                                                                       "visibility_after_embargo" => "open",
                                                                                       "visibility_during_embargo" => "restricted"})
    end
  end
end
