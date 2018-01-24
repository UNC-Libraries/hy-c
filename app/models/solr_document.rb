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

  def academic_department
    self[Solrizer.solr_name('academic_department')]
  end

  def access
    self[Solrizer.solr_name('access')]
  end

  def advisor
    self[Solrizer.solr_name('advisor')]
  end

  def citation
    self[Solrizer.solr_name('citation')]
  end

  def coauthor
    self[Solrizer.solr_name('coauthor')]
  end

  def date_issued
    self[Solrizer.solr_name('date_issued')]
  end

  def date_published
    self[Solrizer.solr_name('date_published')]
  end

  def degree
    self[Solrizer.solr_name('degree')]
  end

  def degree_granting_institution
    self[Solrizer.solr_name('degree_granting_institution')]
  end

  def discipline
    self[Solrizer.solr_name('discipline')]
  end

  def doi
    self[Solrizer.solr_name('doi')]
  end

  def extent
    self[Solrizer.solr_name('extent')]
  end

  def format
    self[Solrizer.solr_name('format')]
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

  def honors_level
    self[Solrizer.solr_name('honors_level')]
  end

  def medium
    self[Solrizer.solr_name('medium')]
  end

  def note
    self[Solrizer.solr_name('note')]
  end

  def orcid
    self[Solrizer.solr_name('orcid')]
  end

  def place_of_publication
    self[Solrizer.solr_name('place_of_publication')]
  end

  def publication
    self[Solrizer.solr_name('publication')]
  end

  def publication_date
    self[Solrizer.solr_name('publication_date')]
  end

  def publication_version
    self[Solrizer.solr_name('publication_version')]
  end

  def record_content_source
    self[Solrizer.solr_name('record_content_source')]
  end

  def reviewer
    self[Solrizer.solr_name('reviewer')]
  end

  def sets
    LanguageSet.sets_for(self)
  end
end
