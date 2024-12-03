# frozen_string_literal: true
module Blacklight
  class ThumbnailPresenter
    private
    # [hyc-override] Retrieve the thumbnail of a document's first file_set instead of using the default if it exists
    def retrieve_values(field_config)
      # Extract the SolrDocument from the document if it's nested
      solr_doc = extract_solr_document(document)
      unless solr_doc
        Rails.logger.warn("Could not extract SolrDocument for document with id #{document.id}")
        return FieldRetriever.new(document, field_config, view_context).fetch
      end

     # Convert SolrDocument to a mutable hash
      document_hash = solr_doc.to_h

      # Update the `thumbnail_path_ss` dynamically if needed
      if needs_thumbnail_path_update?(document_hash)
        file_set_id = document_hash['file_set_ids_ssim']&.first
        document_hash['thumbnail_path_ss'] = "/downloads/#{file_set_id}?file=thumbnail"
        Rails.logger.info("Updated thumbnail_path_ss: #{document_hash['thumbnail_path_ss']} for document with id #{document.id}")
        # Create a temporary SolrDocument from the updated hash
        updated_document = SolrDocument.new(document_hash)
        FieldRetriever.new(updated_document, field_config, view_context).fetch
      else
        FieldRetriever.new(solr_doc, field_config, view_context).fetch
      end
    end

    # Extract the SolrDocument from the document if it's nested
    # Prevents errors when the document is a presenter on work show pages
    def extract_solr_document(doc)
      unless doc
        Rails.logger.warn("Attempted to extract SolrDocument but document is nil for document with id #{doc.id}")
        return nil
      end

      if doc.is_a?(SolrDocument)
        doc
      elsif doc.respond_to?(:solr_document) && doc.solr_document.is_a?(SolrDocument)
        doc.solr_document
      else
        Rails.logger.warn("Unrecognized document type: #{doc.class} for document with id #{doc.id}")
        nil
      end
    end

    def needs_thumbnail_path_update?(document)
      thumbnail_path = document['thumbnail_path_ss'] || ''
      file_set_ids = document['file_set_ids_ssim']

      # Check if the thumbnail path is the default or missing and file_set_ids are present
      thumbnail_path !~ %r{^/downloads/\w+\?file=thumbnail$} && file_set_ids.present?
    end
  end
  end
