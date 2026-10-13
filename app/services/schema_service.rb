# frozen_string_literal: true
# # This service formats information for schema org script tag
module SchemaService
  require 'yaml'

  def self.schema_object(presenter, url)
    schema = {
      '@context' => 'https://schema.org',
      '@type' => self.resource_type(presenter.resource_type.first),
      'name' => self.sanitized_value(presenter.title),
      'description' => self.plain_text(self.sanitized_value(presenter.abstract)),
      'creator' => presenter.creator_display.to_a.map { |person| self.person_details(person) },
      'contributor' => presenter.creator_display.to_a.map { |person| self.person_details(person) },
      'datePublished' => self.sanitized_value(presenter.date_issued),
      'about' => self.about(presenter),
      'keywords' => self.keywords(presenter),
      'license' => self.sanitized_value(presenter.license),
      'inLanguage' => self.language(presenter),
      'identifier' => self.sanitized_value(presenter.doi),
      'publisher' => self.publisher(presenter),
      'contentLocation' => self.location(presenter),
      '@id' => url
    }.compact
    return schema
  end

  def self.person_details(person_string)
    hash = {}
    unc_affiliation = ''
    other_affiliation = ''
    creator_array = person_string.split('||')
    hash['name'] = creator_array[1]
    hash['@type'] = 'Person'
    creator_array.each do |text|
      if text =~ /ORCID:.*?http/
        text_pieces = text.split(' ')
        url = text_pieces[1].strip
        hash['sameAs'] = url
      elsif text =~ /Other Affiliation:/
        other_affiliation = text.delete_prefix('Other Affiliation: ')
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
        unc_affiliation = text.first
      end
    end
    hash['affiliation'] = self.affiliation(unc_affiliation, other_affiliation)
    hash
  end

  def self.resource_type(hyc_value)
    data = YAML.load_file('config/schema_org.yml')
    resource_type = data['schema_org']['resource_type'][hyc_value]
    return resource_type unless resource_type.blank?
    hyc_value
  end

  def self.about(presenter)
    array = []
    subjects = presenter.subject
    subjects.each do |subject|
      array << { '@type' => "Thing", 'name' => subject }
    end
    array
  end

  def self.keywords(presenter)
    array = []
    keywords = presenter.keyword
    keywords.each do |keyword|
      array<< keyword
    end
    array
  end

  def self.affiliation(unc_affiliation, other_affiliation)
    return unc_affiliation if unc_affiliation.present?
    other_affiliation
  end

  def self.language(presenter)
    array = []
    languages = presenter.language
    languages.each do |language|
      array << { '@type' => 'Language', 'name' => language }
    end
    array
  end

  def self.publisher(presenter)
    array = []
    publishers = presenter.publisher
    publishers.each do |publisher|
      array << { '@type' => 'Organization', 'name' => publisher }
    end
    array
  end

  def self.location(presenter)
    location = presenter.based_near_label
    if location.present?
      return { '@type' => 'Place', 'name' => location }
    end
    nil
  end

  def self.sanitized_value(hyc_value)
    return if hyc_value.nil?
    hyc_value.first
  end

  def self.plain_text(value)
    return if value.nil?
    ActionController::Base.helpers.strip_tags(value.to_s)
  end
end
