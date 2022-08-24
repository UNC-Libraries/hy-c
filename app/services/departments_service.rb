# app/services/departments_service.rb
module DepartmentsService
  mattr_accessor :authority
  self.authority = Qa::Authorities::Local.subauthority_for('departments')

  def self.select_all_options
    authority.all.reject { |item| item['active'] == false }.map do |element|
      [element[:id], element[:id]]
    end
  end

  # The permanent identifier for the term, stored in Fedora. This identifier should not be changed.
  def self.identifier(term)
    authority.all.reject { |item| item['active'] == false }.find { |department| department['label'] == term }['id']
  rescue StandardError
    nil
  end

  # The full term associated with the identifier. This is currently used in the display of People objects
  def self.term(id)
    authority.find(id).fetch('term')
  rescue StandardError
    Rails.logger.warn "DepartmentsService: cannot find '#{id}'"
    nil
  end

  # The short version of the term associated with the identifier. These short terms were initially populated with the same
  # values as the identifiers, but unlike the identifiers, these values *can* be changed without negative effects.
  # This values is indexed to solr for department faceting.
  def self.short_label(id)
    authority.find(id).fetch('short_label')
  rescue KeyError
    Rails.logger.warn "DepartmentsService: cannot find '#{id}'"
    nil
  end

  def self.include_current_value(value, _index, render_options, html_options)
    unless value.blank?
      html_options[:class] << ' force-select'
      # Add the current value to the options if it is not already present
      value_index = render_options.index { |opt| opt[0] == value }
      render_options += [[value, value]] if value_index.nil?
    end
    [render_options, html_options]
  end
end
