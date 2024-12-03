# frozen_string_literal: true
module Blacklight
  class ThumbnailPresenter
    private
    # [hyc-override] Retrieve the thumbnail of the first file_set of any given work instead of using the default if it exists
    def retrieve_values(field_config)
      # Return the default thumbnail if the document object is nil
      unless document
        return FieldRetriever.new(document, field_config, view_context).fetch
      end

      solr_doc = extract_solr_document(document)
      document_hash = solr_doc.to_h

      # Update the `thumbnail_path_ss` dynamically if needed
      if needs_thumbnail_path_update?(document_hash)
        file_set_id = document_hash['file_set_ids_ssim']&.first
        document_hash['thumbnail_path_ss'] = "/downloads/#{file_set_id}?file=thumbnail"
        Rails.logger.info("Updated thumbnail_path_ss: #{document_hash['thumbnail_path_ss']} for work with id #{document.id}")
        # Create a temporary SolrDocument from the updated hash
        updated_document = SolrDocument.new(document_hash)
        FieldRetriever.new(updated_document, field_config, view_context).fetch
      else
        FieldRetriever.new(solr_doc, field_config, view_context).fetch
      end
    end

    # Extract the SolrDocument from the document object if it's nested
    # Prevents errors when the document object is a presenter on work show pages
    def extract_solr_document(doc)
      if doc.is_a?(SolrDocument)
        doc
      elsif doc.respond_to?(:solr_document) && doc.solr_document.is_a?(SolrDocument)
        doc.solr_document
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
