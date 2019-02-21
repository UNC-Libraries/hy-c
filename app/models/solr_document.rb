# frozen_string_literal: true
class SolrDocument
  include Blacklight::Solr::Document
  include BlacklightOaiProvider::SolrDocument

  use_extension Blacklight::Document::DublinCore

  include Blacklight::Gallery::OpenseadragonSolrDocument

  # Adds Hyrax behaviors to the SolrDocument.
  include Hyrax::SolrDocumentBehavior


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
      creator:     'creator_tesim',
      contributor: 'contributor_tesim',
      coverage:    'coverage_tesim',
      date:        'date_created_tesim',
      description: 'description_tesim',
      format:      'format_tesim',
      identifier:  'identifier_tesim',
      language:    'language_tesim',
      publisher:   'publisher_tesim',
      relation:    'relation_tesim',
      rights_statement: 'rights_statement_tesim',
      source:      'source_tesim',
      subject:     'subject_tesim',
      title:       'title_tesim',
      type:        'resource_type_tesim')


  # Do content negotiation for AF models. 

  use_extension( Hydra::ContentNegotiation )

  def abstract
    self[Solrizer.solr_name('abstract')]
  end

  def academic_concentration
    self[Solrizer.solr_name('academic_concentration')]
  end

  def access
    self[Solrizer.solr_name('access')]
  end

  def advisor
    self[Solrizer.solr_name('advisor')]
  end

  def advisor_display
    self[Solrizer.solr_name('advisor_display')]
  end

  def advisor_label
    self[Solrizer.solr_name('advisor_label')]
  end

  def affiliation
    self[Solrizer.solr_name('affiliation')]
  end

  def affiliation_label
    self[Solrizer.solr_name('affiliation_label')]
  end

  def alternative_title
    self[Solrizer.solr_name('alternative_title')]
  end

  def arranger
    self[Solrizer.solr_name('arranger')]
  end

  def arranger_display
    self[Solrizer.solr_name('arranger_display')]
  end

  def award
    self[Solrizer.solr_name('award')]
  end

  def bibliographic_citation
    self[Solrizer.solr_name('bibliographic_citation')]
  end

  def composer
    self[Solrizer.solr_name('composer')]
  end

  def composer_display
    self[Solrizer.solr_name('composer_display')]
  end

  def contributor_display
    self[Solrizer.solr_name('contributor_display')]
  end

  def conference_name
    self[Solrizer.solr_name('conference_name')]
  end

  def copyright_date
    self[Solrizer.solr_name('copyright_date')]
  end

  def creator_display
    self[Solrizer.solr_name('creator_display')]
  end

  def creator_label
    self[Solrizer.solr_name('creator_label')]
  end

  def date_captured
    self[Solrizer.solr_name('date_captured')]
  end

  def date_issued
    self[Solrizer.solr_name('date_issued')]
  end

  def date_other
    self[Solrizer.solr_name('date_other')]
  end

  def degree
    self[Solrizer.solr_name('degree')]
  end

  def degree_granting_institution
    self[Solrizer.solr_name('degree_granting_institution')]
  end

  def deposit_record
    self[Solrizer.solr_name('deposit_record')]
  end

  def digital_collection
    self[Solrizer.solr_name('digital_collection')]
  end

  def discipline
    self[Solrizer.solr_name('discipline')]
  end

  def doi
    self[Solrizer.solr_name('doi')]
  end

  def edition
    self[Solrizer.solr_name('edition')]
  end

  def extent
    self[Solrizer.solr_name('extent')]
  end

  def funder
    self[Solrizer.solr_name('funder')]
  end

  def dcmi_type
    self[Solrizer.solr_name('dcmi_type')]
  end

  def geographic_subject
    self[Solrizer.solr_name('geographic_subject')]
  end

  def graduation_year
    self[Solrizer.solr_name('graduation_year')]
  end

  def honors_concentration
    self[Solrizer.solr_name('honors_concentration')]
  end

  def isbn
    self[Solrizer.solr_name('isbn')]
  end

  def issn
    self[Solrizer.solr_name('issn')]
  end

  def journal_issue
    self[Solrizer.solr_name('journal_issue')]
  end

  def journal_title
    self[Solrizer.solr_name('journal_title')]
  end

  def journal_volume
    self[Solrizer.solr_name('journal_volume')]
  end

  def kind_of_data
    self[Solrizer.solr_name('kind_of_data')]
  end

  def language_label
    self[Solrizer.solr_name('language_label')]
  end

  def last_modified_date
    self[Solrizer.solr_name('last_modified_date')]
  end

  def license_label
    self[Solrizer.solr_name('license_label')]
  end

  def medium
    self[Solrizer.solr_name('medium')]
  end

  def methodology
    self[Solrizer.solr_name('methodology')]
  end

  def note
    self[Solrizer.solr_name('note')]
  end

  def orcid
    self[Solrizer.solr_name('orcid')]
  end

  def orcid_label
    self[Solrizer.solr_name('orcid_label')]
  end

  def other_affiliation
    self[Solrizer.solr_name('other_affiliation')]
  end

  def other_affiliation_label
    self[Solrizer.solr_name('other_affiliation_label')]
  end

  def page_end
    self[Solrizer.solr_name('page_end')]
  end

  def page_start
    self[Solrizer.solr_name('page_start')]
  end

  def peer_review_status
    self[Solrizer.solr_name('peer_review_status')]
  end

  def person_label
    self[Solrizer.solr_name('person_label')]
  end

  def place_of_publication
    self[Solrizer.solr_name('place_of_publication')]
  end

  def project_director
    self[Solrizer.solr_name('project_director')]
  end

  def project_director_display
    self[Solrizer.solr_name('project_director_display')]
  end

  def publisher_version
    self[Solrizer.solr_name('publisher_version')]
  end

  def researcher
    self[Solrizer.solr_name('researcher')]
  end

  def researcher_display
    self[Solrizer.solr_name('researcher_display')]
  end

  def reviewer
    self[Solrizer.solr_name('reviewer')]
  end

  def reviewer_display
    self[Solrizer.solr_name('reviewer_display')]
  end

  def rights_holder
    self[Solrizer.solr_name('rights_holder')]
  end

  def rights_statement_label
    self[Solrizer.solr_name('rights_statement_label')]
  end

  def sets
    LanguageSet.sets_for(self)
  end

  def series
    self[Solrizer.solr_name('series')]
  end

  def sponsor
    self[Solrizer.solr_name('sponsor')]
  end

  def table_of_contents
    self[Solrizer.solr_name('table_of_contents')]
  end

  def translator
    self[Solrizer.solr_name('translator')]
  end

  def translator_display
    self[Solrizer.solr_name('translator_display')]
  end

  def url
    self[Solrizer.solr_name('url')]
  end

  def use
    self[Solrizer.solr_name('use')]
  end
end
