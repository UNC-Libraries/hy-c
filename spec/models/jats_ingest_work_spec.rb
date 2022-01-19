require 'rails_helper'

RSpec.describe JatsIngestWork, :sage, type: :model do
  let(:xml_file_path) { File.join(fixture_path, 'sage', 'CCX_2021_28_10.1177_1073274820985792', '10.1177_1073274820985792.xml') }
  let(:work) { described_class.new(xml_path: xml_file_path) }

  context 'when it can\'t match the license' do
    it "can return the license info" do
      allow(CdrLicenseService.authority).to receive(:find).and_return({})
      expect(work.license).to eq([])
    end
  end

  it 'can be initialized' do
    expect(described_class.new(xml_path: xml_file_path)).to be_instance_of described_class
  end

  it 'has xml' do
    expect(Nokogiri::XML(work.jats_xml)).to be_instance_of Nokogiri::XML::Document
  end

  it 'can create a properly constructed person object' do
    expect(work.creators).to be_instance_of Hash
    expect(work.creators.count).to eq 6
    expect(work.creators[0]).to be_instance_of Hash
    expect(work.creators[0]).to include('name' => 'Holt, Hunter K.')
    expect(work.creators[0]).to include('orcid' => 'https://orcid.org/0000-0001-6833-8372')
    expect(work.creators[2]).to include('name' => 'Hu, Shang-Ying')
    expect(work.creators[2]).to include('index' => '3')
    expect(work.creators[2]).to include('orcid' => '')
    expect(work.creators[2]).to include('other_affiliation' => /Department of Cancer Epidemiology/)
    expect(work.creators[0]).to include('affiliation' => '')
    expect(work.creators[0]).to include('other_affiliation' => 'Department of Family and Community Medicine, University of California, San Francisco, CA, USA')
    expect(work.creators[4]).to include('name' => 'Smith, Jennifer S.')
    expect(work.creators[4]).to include('index' => '5')
    expect(work.creators[4]).to include('other_affiliation' => 'Department of Epidemiology, UNC Gillings School of Global Public Health, Chapel Hill, NC, USA')
  end

  it 'can map UNC affiliations to the controlled vocabulary' do
    pending('Mapping from Sage affiliations to UNC controlled vocabulary')
    expect(work.creators[4]).to include('affiliation' => 'Gillings School of Global Public Health; Department of Epidemiology')
  end

  it 'can map affiliation ids to institution names' do
    expect(work.affiliation_map).to be_instance_of Hash
    expect(work.affiliation_map['aff1-1073274820985792']).to eq('Department of Family and Community Medicine, University of California, San Francisco, CA, USA')
  end

  it 'returns arrays for multi-valued fields and strings for single value fields' do
    expect(work.abstract).to be_instance_of Array
    expect(work.copyright_date).to be_instance_of String
    expect(work.date_of_publication).to be_instance_of String
    expect(work.funder).to be_instance_of Array
    expect(work.identifier).to be_instance_of Array
    expect(work.issn).to be_instance_of Array
    expect(work.journal_issue).to be nil
    expect(work.journal_title).to be_instance_of String
    expect(work.journal_volume).to be_instance_of String
    expect(work.keyword).to be_instance_of Array
    expect(work.license).to be_instance_of Array
    expect(work.license_label).to be_instance_of Array
    expect(work.page_end).to be nil
    expect(work.page_start).to be nil
    expect(work.publisher).to be_instance_of Array
    expect(work.rights_holder).to be_instance_of Array
    expect(work.title).to be_instance_of Array
  end

  it 'can return metadata from the xml' do
    expect(work.abstract.first).to include 'provinces across China and administered a questionnaire'
    expect(work.copyright_date).to eq '2021'
    expect(work.date_of_publication).to eq '2021-02-01'
    expect(work.funder).to eq ['Fogarty International Center']
    expect(work.identifier).to eq ['https://doi.org/10.1177/1073274820985792']
    expect(work.issn).to eq ['1073-2748']
    expect(work.journal_issue).to be nil
    expect(work.journal_title).to eq 'Cancer Control'
    expect(work.journal_volume).to eq '28'
    expect(work.keyword).to match_array(['HPV', 'HPV knowledge and awareness', 'cervical cancer screening', 'migrant women', 'China'])
    expect(work.license).to eq(['http://creativecommons.org/licenses/by-nc/4.0/'])
    expect(work.page_end).to be nil
    expect(work.page_start).to be nil
    expect(work.publisher).to eq ['SAGE Publications']
    # expect(work.resource_type).to eq(['Article'])
    expect(work.rights_holder).to eq(['SAGE Publications Inc, unless otherwise noted. Manuscript content on this site is licensed under Creative Common Licences'])
    expect(work.title).to eq(['Inequalities in Cervical Cancer Screening Uptake Between Chinese Migrant Women and Local Women: A Cross-Sectional Study'])
  end

  it 'can map to the controlled license vocabulary' do
    expect(work.license).to eq(['http://creativecommons.org/licenses/by-nc/4.0/'])
    expect(work.license_label).to eq ['Attribution-NonCommercial 4.0 International']
  end

  context 'with an article that has a physical print' do
    let(:xml_file_path) { File.join(fixture_path, 'sage', '10.1177_2192568219888179.xml') }

    it 'can return metadata from the xml' do
      expect(work.abstract.first).to include 'patients undergoing elective ACDF were prospectively enrolled'
      expect(work.copyright_date).to eq '2019'
      expect(work.date_of_publication).to eq '2021-01'
      expect(work.funder).to eq []
      expect(work.identifier).to eq ['https://doi.org/10.1177/2192568219888179']
      expect(work.issn).to eq ['2192-5682', '2192-5690']
      expect(work.journal_issue).to eq '1'
      expect(work.journal_title).to eq 'Global Spine Journal'
      expect(work.journal_volume).to eq '11'
      expect(work.keyword).to match_array(['degenerative cervical conditions', 'Propionibacterium acnes', 'contaminant control', 'intervertebral disc infection', 'disc cultures', 'anterior cervical discectomy and fusion', 'revision surgery'])
      expect(work.license).to eq(['http://creativecommons.org/licenses/by-nc-nd/4.0/'])
      expect(work.license_label).to eq(['Attribution-NonCommercial-NoDerivatives 4.0 International'])
      expect(work.page_end).to eq '20'
      expect(work.page_start).to eq '13'
      expect(work.publisher).to eq ['SAGE Publications']
      expect(work.rights_holder).to eq(['AO Spine, unless otherwise noted. Manuscript content on this site is licensed under Creative Commons Licenses'])
      expect(work.title).to eq(['The Prevalence of Bacterial Infection in Patients Undergoing Elective ACDF for Degenerative Cervical Spine Conditions: A Prospective Cohort Study With Contaminant Control'])
    end
  end
end
