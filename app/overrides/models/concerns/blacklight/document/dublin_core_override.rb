# frozen_string_literal: true
# [hyc-override] https://github.com/projectblacklight/blacklight/tree/v7.33.1/app/models/concerns/blacklight/document/dublin_core.rb
Blacklight::Document::DublinCore.module_eval do
  include HycHelper

  # [hyc-override] added thumbnail as separate field to help with ordering
  def dublin_core_field_names
    [:contributor, :coverage, :creator, :date, :description, :format, :identifier, :language, :publisher, :relation,
     :rights, :source, :subject, :title, :type, :thumbnail]
  end

  # [hyc-override] format values for display in oai feed
  # dublin core elements are mapped against the #dublin_core_field_names allowlist.
  def export_as_oai_dc_xml
    xml = Builder::XmlMarkup.new
    xml.tag!('oai_dc:dc',
             'xmlns:oai_dc' => 'http://www.openarchives.org/OAI/2.0/oai_dc/',
             'xmlns:dc' => 'http://purl.org/dc/elements/1.1/',
             'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
             'xsi:schemaLocation' => %(http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd)) do
      to_semantic_values.select { |field, _values| dublin_core_field_name? field  }.each do |field, values|
        field_s = field.to_s
        if field_s == 'thumbnail'
          add_thumbnail_to_xml(xml, values)
        else
          array_of_values = values_as_array(values)
          if field_s == 'source'
            add_source_to_xml(xml, array_of_values)
          else
            array_of_values.each { |v| add_field_to_xml(xml, field_s, v) }
          end
        end
      end
    end

    xml.target!
  end

  def values_as_array(values)
    # sort people by index value
    if Array.wrap(values).first.match('index:')
      array_of_values = sort_people_by_index(values)
      array_of_values.map! { |value| value.gsub(/\Aindex:\d*\|\|/, '') }
    else
      array_of_values = Array.wrap(values)
    end
  end

  def add_field_to_xml(xml, field, v)
    if field == 'creator' || field == 'contributor'
      xml.tag! "dc:#{field}", v.to_s.split('||').first
    else
      xml.tag! "dc:#{field}", v
    end
  end

  def add_thumbnail_to_xml(xml, values)
    if doi.blank?
      record_url = URI.join(ENV['HYRAX_HOST'], "concern/#{first('has_model_ssim').tableize}/#{id}").to_s
      xml.tag! 'dc:identifier', record_url
    end
    thumb_download = values.first
    xml.tag! 'dc:identifier', "#{ENV['HYRAX_HOST']}#{thumb_download}"
    file_download = thumb_download.split('?').first
    xml.tag! 'dc:identifier', "#{ENV['HYRAX_HOST']}#{file_download}"
  end

  def add_source_to_xml(xml, array_of_values)
    return if array_of_values.blank?
    source = array_of_values.map { |v| v.to_s }

    # Based on tests in blacklight, the journal information should always be returned in the order listed in app/models/solr_document.rb
    if source.count == 3
      xml.tag! 'dc:source', "#{source[0]}, #{source[1]}(#{source[2]})"
    else
      xml.tag! 'dc:source', source.join(', ')
    end
  end

  # [hyc-override] Used by ruby-oai gem to determine if a status=deleted header should be added.
  # See OAI::Provider::Response::RecordResponse
  def deleted?
    fetch('workflow_state_name_ssim', nil)&.include?('withdrawn')
  end
end
