# frozen_string_literal: true

module Blacklight
  class ThumbnailPresenter
    attr_reader :document, :view_context, :view_config

    # @param [SolrDocument] document
    # @param [ActionView::Base] view_context scope for linking and generating urls
    #                                        as well as for invoking "thumbnail_method"
    # @param [Blacklight::Configuration::ViewConfig] view_config
    def initialize(document, view_context, view_config)
      @document = document
      @view_context = view_context
      @view_config = view_config
    end

    def render(image_options = {})
      thumbnail_value(image_options)
    end

    ##
    # Does the document have a thumbnail to render?
    #
    # @return [Boolean]
    def exists?
      thumbnail_method.present? ||
        (thumbnail_field && thumbnail_value_from_document.present?) ||
        default_thumbnail.present?
    end

    ##
    # Render the thumbnail, if available, for a document and
    # link it to the document record.
    #
    # @param [Hash] image_options to pass to the image tag
    # @param [Hash] url_options to pass to #link_to_document
    # @return [String]
    def thumbnail_tag(image_options = {}, url_options = {})
      value = thumbnail_value(image_options)
      return value if value.nil? || url_options[:suppress_link]

      view_context.link_to_document document, value, url_options
    end

    private

    delegate :thumbnail_field, :thumbnail_method, :default_thumbnail, to: :view_config

    # @param [Hash] image_options to pass to the image tag
    def thumbnail_value(image_options)
      value = if thumbnail_method
                view_context.send(thumbnail_method, document, image_options)
              elsif thumbnail_field
                image_url = thumbnail_value_from_document
                view_context.image_tag image_url, image_options if image_url.present?
              end

      value || default_thumbnail_value(image_options)
    end

    def default_thumbnail_value(image_options)
      return unless default_thumbnail

      case default_thumbnail
      when Symbol
        view_context.send(default_thumbnail, document, image_options)
      when Proc
        default_thumbnail.call(document, image_options)
      else
        view_context.image_tag default_thumbnail, image_options
      end
    end

    def thumbnail_value_from_document
      Array(thumbnail_field).lazy.map { |field| retrieve_values(field_config(field)).first }.compact_blank.first
    end

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

    def extract_solr_document(doc)
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

    def field_config(field)
      return field if field.is_a? Blacklight::Configuration::Field

      Configuration::NullField.new(field)
    end
  end
  end
