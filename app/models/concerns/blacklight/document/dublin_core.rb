# [hyc-override] override file from blacklight gem
# frozen_string_literal: true
require 'builder'

# This module provides Dublin Core export based on the document's semantic values
module Blacklight::Document::DublinCore
  include HycHelper

  def self.extended(document)
    # Register our exportable formats
    Blacklight::Document::DublinCore.register_export_formats(document)
  end

  def self.register_export_formats(document)
    document.will_export_as(:xml)
    document.will_export_as(:dc_xml, "text/xml")
    document.will_export_as(:oai_dc_xml, "text/xml")
  end

  # added thumbnail as separate field to help with ordering
  def dublin_core_field_names
    [:contributor, :coverage, :creator, :date, :description, :format, :identifier, :language, :publisher, :relation,
     :rights, :source, :subject, :title, :type, :thumbnail]
  end

  # [hyc-override] format values for display in oai feed
  # dublin core elements are mapped against the #dublin_core_field_names whitelist.
  def export_as_oai_dc_xml
    xml = Builder::XmlMarkup.new
    xml.tag!("oai_dc:dc",
             'xmlns:oai_dc' => "http://www.openarchives.org/OAI/2.0/oai_dc/",
             'xmlns:dc' => "http://purl.org/dc/elements/1.1/",
             'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance",
             'xsi:schemaLocation' => %(http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd)) do
      to_semantic_values.select { |field, _values| dublin_core_field_name? field  }.each do |field, values|
        source = []
        # sort people by index value
        array_of_values = []
        if Array.wrap(values).first.match('index:')
          array_of_values = sort_people_by_index(values)
          array_of_values.map!{|value| value.gsub(/\Aindex:\d*\|\|/, '')}
        else
          array_of_values = Array.wrap(values)
        end
        array_of_values.each do |v|
          if field.to_s == 'creator'
            xml.tag! "dc:#{field}", v.to_s.split('||').first
            affiliation = v.to_s.split('||Affiliation: ')[1]
            if !affiliation.blank?
              xml.tag! "dc:contributor", affiliation.split('||').first
            end
          elsif field.to_s == 'contributor'
            xml.tag! "dc:#{field}", v.to_s.split('||').first
          # display journal values as comma separated string (journal values come from single-valued fields)
          elsif field.to_s == 'source'
            source << v.to_s
          elsif field.to_s == 'thumbnail'
            if doi.blank?
              record_url = URI.join(ENV['HYRAX_HOST'], "concern/#{first('has_model_ssim').tableize}/#{id()}").to_s
              xml.tag! "dc:identifier", record_url
            end
            thumb_download = (values.first)
            xml.tag! 'dc:identifier', "#{ENV['HYRAX_HOST']}#{thumb_download}"
            file_download = thumb_download.split('?').first
            xml.tag! 'dc:identifier', "#{ENV['HYRAX_HOST']}#{file_download}"
          else
            xml.tag! "dc:#{field}", v
          end
        end
        if !source.blank?
          # Based on tests in blacklight, the journal information should always be returned in the order listed in app/models/solr_document.rb
          if source.count == 3
            xml.tag! "dc:source", "#{source[0]}, #{source[1]}(#{source[2]})"
          else
            xml.tag! "dc:source", source.join(', ')
          end
        end
      end
    end

    xml.target!
  end

  alias_method :export_as_xml, :export_as_oai_dc_xml
  alias_method :export_as_dc_xml, :export_as_oai_dc_xml

  # Used by ruby-oai gem to determine if a status=deleted header should be added.
  # See OAI::Provider::Response::RecordResponse
  def deleted?
    fetch('workflow_state_name_ssim', nil)&.include?('withdrawn')
  end

  private

  def dublin_core_field_name? field
    dublin_core_field_names.include? field.to_sym
  end
end
