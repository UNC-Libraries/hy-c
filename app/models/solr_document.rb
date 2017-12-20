# frozen_string_literal: true
class SolrDocument
  include Blacklight::Solr::Document
  include BlacklightOaiProvider::SolrDocumentBehavior

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

  def additional_funding
    self[Solrizer.solr_name('additional_funding')]
  end

  def advisor
    self[Solrizer.solr_name('advisor')]
  end

  def author_degree_granted
    self[Solrizer.solr_name('author_degree_granted')]
  end

  def author_academic_concentration
    self[Solrizer.solr_name('author_academic_concentration')]
  end

  def author_graduation_date
    self[Solrizer.solr_name('author_graduation_date')]
  end

  def author_status
    self[Solrizer.solr_name('author_status')]
  end

  def citation
    self[Solrizer.solr_name('citation')]
  end

  def coauthor
    self[Solrizer.solr_name('coauthor')]
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

  def doi
    self[Solrizer.solr_name('doi')]
  end

  def faculty_advisor_name
    self[Solrizer.solr_name('faculty_advisor_name')]
  end

  def genre
    self[Solrizer.solr_name('genre')]
  end

  def graduation_year
    self[Solrizer.solr_name('graduation_year')]
  end

  def granting_agency
    self[Solrizer.solr_name('granting_agency')]
  end

  def honors_level
    self[Solrizer.solr_name('honors_level')]
  end

  def issue
    self[Solrizer.solr_name('issue')]
  end

  def institution
    self[Solrizer.solr_name('institution')]
  end

  def link_to_publisher_version
    self[Solrizer.solr_name('link_to_publisher_version')]
  end

  def note
    self[Solrizer.solr_name('note')]
  end

  def orcid
    self[Solrizer.solr_name('orcid')]
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

  def sets
    fetch('language_tesim', []).map { |l| BlacklightOaiProvider::Set.new("language_tesim:#{l}") }
  end
end
