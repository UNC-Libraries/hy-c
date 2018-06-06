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
      rights:      'rights_statement_tesim',
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

  def alternative_title
    self[Solrizer.solr_name('alternative_title')]
  end

  def arranger
    self[Solrizer.solr_name('arranger')]
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

  def conference_name
    self[Solrizer.solr_name('conference_name')]
  end

  def copyright_date
    self[Solrizer.solr_name('copyright_date')]
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

  def genre
    self[Solrizer.solr_name('genre')]
  end

  def geographic_subject
    self[Solrizer.solr_name('geographic_subject')]
  end

  def graduation_year
    self[Solrizer.solr_name('graduation_year')]
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

  def last_modified_date
    self[Solrizer.solr_name('last_modified_date')]
  end

  def medium
    self[Solrizer.solr_name('medium')]
  end

  def note
    self[Solrizer.solr_name('note')]
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

  def place_of_publication
    self[Solrizer.solr_name('place_of_publication')]
  end

  def project_director
    self[Solrizer.solr_name('project_director')]
  end

  def researcher
    self[Solrizer.solr_name('researcher')]
  end

  def reviewer
    self[Solrizer.solr_name('reviewer')]
  end

  def rights_holder
    self[Solrizer.solr_name('rights_holder')]
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

  def url
    self[Solrizer.solr_name('url')]
  end

  def use
    self[Solrizer.solr_name('use')]
  end
end
