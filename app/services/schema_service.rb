# frozen_string_literal: true
# # This service formats information for schema org script tag
module SchemaService
  require 'yaml'

  def self.person_details(person_string)
    array = {}
    creator_array = person_string.split('||')
    array[:name] = creator_array[1]
    creator_array.each do |text|
      if text =~ /ORCID:.*?http/
        text_pieces = text.split(' ')
        url = text_pieces[1].strip
        array[:orcid] = url
      elsif text =~ /Affiliation:/
        # Get the full hierarchy of terms, with correct short labels, for the affiliation id
        term = DepartmentsService.term(text.split(':').last.strip)
        if term.present?
          text = Array(term).map { |t| t.split(';') }.map do |term_list|
            term_list.map do |term_val|
              DepartmentsService.short_label(term_val.strip) || term_val.strip
            end.join(', ')
          end
        end
        array[:affiliation] = text.first
      end
    end
    array
  end

  def self.resource_type(hyc_value)
    data = YAML.load_file('config/schema_org.yml')
    return data['schema_org']['resource_type'][hyc_value]
  end

  def self.sanitized_value(hyc_value)
    return nil if hyc_value.nil?
    hyc_value.first
  end
end
