# frozen_string_literal: true
module Tasks
    # Abstract base for attribute builders for newly ingested articles
  class BaseAttributeBuilder
    attr_reader :metadata, :article, :admin_set, :depositor_onyen

    def initialize(metadata, article, admin_set, depositor_onyen)
      @metadata = metadata
      @article = article
      @admin_set = admin_set
      @depositor_onyen = depositor_onyen
    end

    def populate_article_metadata
      set_rights_and_types
      set_basic_attributes
      set_journal_attributes
      set_identifiers
      article
    end


    def find_skipped_row(new_pubmed_works)
      raise NotImplementedError
    end

    def get_date_issued
      raise NotImplementedError
    end

      private

    def set_basic_attributes
      article.admin_set = admin_set
      article.depositor = depositor_onyen
      article.resource_type = ['Article']
      article.creators_attributes = generate_authors
      apply_additional_basic_attributes
    end

    def set_rights_and_types
      rights_statement = 'http://rightsstatements.org/vocab/InC/1.0/'
      article.rights_statement = rights_statement
      article.rights_statement_label = CdrRightsStatementsService.label(rights_statement)
      article.dcmi_type = ['http://purl.org/dc/dcmitype/Text']
    end

    def generate_authors
      raise NotImplementedError
    end

    def retrieve_author_affiliations(hash, author)
      raise NotImplementedError
    end

    def apply_additional_basic_attributes
      raise NotImplementedError
    end

    def set_identifiers
      raise NotImplementedError
    end

    def format_publication_identifiers
      raise NotImplementedError
    end

    def set_journal_attributes
      raise NotImplementedError
    end
  end
end
