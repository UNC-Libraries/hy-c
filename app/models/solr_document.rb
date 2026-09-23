# frozen_string_literal: true

class SolrDocument
  include Blacklight::Solr::Document
  include BlacklightOaiProvider::SolrDocument

  use_extension Blacklight::Document::DublinCore

  include Blacklight::Gallery::OpenseadragonSolrDocument

  # Adds Hyrax behaviors to the SolrDocument.
  include Hyrax::SolrDocumentBehavior

  # Add RIS export behavior to the SolrDocument.
  include Blacklight::Ris::DocumentFields
  use_extension(Blacklight::Ris::DocumentExport)

  # self.unique_key = 'id'

  # Email uses the semantic field mappings below to generate the body of an email.
  SolrDocument.use_extension(Blacklight::Document::Email)

  # SMS uses the semantic field mappings below to generate the body of an SMS email.
  SolrDocument.use_extension(Blacklight::Document::Sms)

  # DublinCore uses the semantic field mappings below to assemble an OAI-compliant Dublin Core document
  # Semantic mappings of solr stored fields. Fields may be multi or
  # single valued. See Blacklight::Document::SemanticFields#field_semantics
  # and Blacklight::Document::SemanticFields#to_semantic_values
  # Recommendation: Use field names from Dublin Core
  use_extension(Blacklight::Document::DublinCore)

  field_semantics.merge!(
    title: 'title_tesim',
    creator: ['creator_display_tesim', 'composer_display_tesim'],
    contributor: ['contributor_display_tesim', 'advisor_display_tesim', 'arranger_display_tesim',
                  'project_director_display_tesim', 'researcher_display_tesim', 'reviewer_display_tesim',
                  'translator_display_tesim'],
    publisher: ['publisher_tesim', 'degree_granting_institution_tesim'],
    date: ['date_issued_edtf_tesim', 'graduation_year_tesim'],
    description: ['abstract_tesim', 'degree_tesim'],
    subject: ['subject_tesim', 'keyword_tesim'],
    coverage: 'based_near_label_tesim',
    language: 'language_label_tesim',
    type: 'resource_type_tesim',
    rights: ['rights_statement_tesim', 'license_tesim'],
    identifier: 'doi_tesim',
    source: ['journal_title_tesim', 'journal_volume_tesim', 'journal_issue_tesim'],
    thumbnail: 'thumbnail_path_ss')

  # Do content negotiation for AF models.

  use_extension(Hydra::ContentNegotiation)

  # Configure RIS export behavior for the SolrDocument.
  RIS_TYPE_MAPPINGS = {
    '3D Object' => 'GEN',
    'Art' => 'ART',
    'Article' => 'JOUR',
    'Audio' => 'SOUND',
    'Book' => 'BOOK',
    'Capstone Project' => 'THES',
    'Conference Proceeding' => 'CONF',
    'Dataset' => 'DATA',
    'Dissertation' => 'THES',
    'Educational Resource' => 'ELEC',
    'Honors Thesis' => 'THES',
    'Image' => 'IMG',
    'Journal' => 'JFULL',
    'Journal Item' => 'JOUR',
    'Map or Cartographic Material' => 'MAP',
    'Masters Paper' => 'THES',
    'Masters Thesis' => 'THES',
    'Newsletter' => 'NEWS',
    'Other' => 'GEN',
    'Part of Book' => 'CHAP',
    'Poster' => 'SLIDE',
    'Presentation'  => 'SLIDE',
    'Project' => 'RPRT',
    'Report' => 'RPRT',
    'Research Paper' => 'RPRT',
    'Research Protocol' => 'RPRT',
    'Software or Program Code' => 'COMP',
    'Undergraduate Thesis' => 'THES',
    'Video' => 'VIDEO',
    'Working Paper' => 'RPRT'
  }.freeze

  # Author should be the second key. Just return everything if there is no second key.
  def self.format_author(name)
    author = name.split('||')[1] || name.split('||')[0]
    author.strip
  end

  def self.format_ris_type(resource_type)
    RIS_TYPE_MAPPINGS.fetch(resource_type, 'GEN')
  end

  # Configure RIS field mappings.
  def self.ris_mappings
    {
      AU: proc do |doc|
        Array(doc['creator_display_tesim']).map do |name|
          SolrDocument.format_author(name)
        end
      end,
      DO: 'doi_tesim',
      EP: 'journal_end_page_tesim',
      ID: 'identifier_tesim',
      IS: 'journal_issue_tesim',
      JF: 'journal_title_tesim',
      KW: 'keyword_tesim',
      LA: 'language_label_tesim',
      M3: 'medium_tesim',
      PB: 'publisher_tesim',
      PY: 'date_issued_edtf_tesim',
      SN: 'issn_tesim',
      SP: 'journal_start_page_tesim',
      TI: 'title_tesim',
      TY: proc do |doc|
        SolrDocument.format_ris_type(Array(doc['resource_type_tesim']).first)
      end,
      VL: 'journal_volume_tesim'
    }
  end

  ris_field_mappings.merge!(ris_mappings)

  def abstract
    self['abstract_tesim']
  end

  def academic_concentration
    self['academic_concentration_tesim']
  end

  def admin_note
    self['admin_note_tesim']
  end

  def advisor
    self['advisor_tesim']
  end

  def advisor_display
    self['advisor_display_tesim']
  end

  def advisor_label
    self['advisor_label_tesim']
  end

  def affiliation
    self['affiliation_tesim']
  end

  def affiliation_label
    self['affiliation_label_tesim']
  end

  def alternative_title
    self['alternative_title_tesim']
  end

  def arranger
    self['arranger_tesim']
  end

  def arranger_display
    self['arranger_display_tesim']
  end

  def award
    self['award_tesim']
  end

  def bibliographic_citation
    self['bibliographic_citation_tesim']
  end

  def composer
    self['composer_tesim']
  end

  def composer_display
    self['composer_display_tesim']
  end

  def contributor_display
    self['contributor_display_tesim']
  end

  def contributor_label
    self['contributor_label_tesim']
  end

  def conference_name
    self['conference_name_tesim']
  end

  def copyright_date
    self['copyright_date_tesim']
  end

  def creator_display
    self['creator_display_tesim']
  end

  def creator_label
    self['creator_label_tesim']
  end

  def date_captured
    self['date_captured_tesim']
  end

  def date_issued
    self['date_issued_tesim']
  end

  def date_issued_edtf
    self['date_issued_edtf_tesim']
  end

  def date_other
    self['date_other_tesim']
  end

  def degree
    self['degree_tesim']
  end

  def degree_granting_institution
    self['degree_granting_institution_tesim']
  end

  def deposit_record
    self['deposit_record_tesim']
  end

  def digital_collection
    self['digital_collection_tesim']
  end

  def discipline
    self['discipline_tesim']
  end

  def doi
    self['doi_tesim']
  end

  def edition
    self['edition_tesim']
  end

  def extent
    self['extent_tesim']
  end

  def funder
    self['funder_tesim']
  end

  def dcmi_type
    self['dcmi_type_tesim']
  end

  def graduation_year
    self['graduation_year_tesim']
  end

  def isbn
    self['isbn_tesim']
  end

  def issn
    self['issn_tesim']
  end

  def journal_issue
    self['journal_issue_tesim']
  end

  def journal_title
    self['journal_title_tesim']
  end

  def journal_volume
    self['journal_volume_tesim']
  end

  def kind_of_data
    self['kind_of_data_tesim']
  end

  def language_label
    self['language_label_tesim']
  end

  def last_modified_date
    self['last_modified_date_tesim']
  end

  def license_label
    self['license_label_tesim']
  end

  def medium
    self['medium_tesim']
  end

  def methodology
    self['methodology_tesim']
  end

  def note
    self['note_tesim']
  end

  def orcid
    self['orcid_tesim']
  end

  def orcid_label
    self['orcid_label_tesim']
  end

  def other_affiliation
    self['other_affiliation_tesim']
  end

  def other_affiliation_label
    self['other_affiliation_label_tesim']
  end

  def page_end
    self['page_end_tesim']
  end

  def page_start
    self['page_start_tesim']
  end

  def peer_review_status
    self['peer_review_status_tesim']
  end

  def person_label
    self['person_label_tesim']
  end

  def place_of_publication
    self['place_of_publication_tesim']
  end

  def project_director
    self['project_director_tesim']
  end

  def project_director_display
    self['project_director_display_tesim']
  end

  def researcher
    self['researcher_tesim']
  end

  def researcher_display
    self['researcher_display_tesim']
  end

  def reviewer
    self['reviewer_tesim']
  end

  def reviewer_display
    self['reviewer_display_tesim']
  end

  def rights_holder
    self['rights_holder_tesim']
  end

  def rights_statement_label
    self['rights_statement_label_tesim']
  end

  def sets
    CdrListSet.sets_for(self)
  end

  def series
    self['series_tesim']
  end

  def sponsor
    self['sponsor_tesim']
  end

  def table_of_contents
    self['table_of_contents_tesim']
  end

  def translator
    self['translator_tesim']
  end

  def translator_display
    self['translator_display_tesim']
  end

  def url
    self['url_tesim']
  end

  def wcag_compliance
    self['wcag_compliance_tesim']
  end
end
