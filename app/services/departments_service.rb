# app/services/departments_service.rb
module DepartmentsService
  mattr_accessor :authority
  self.authority = Qa::Authorities::Local.subauthority_for('departments')

  def self.select_all_options
    authority.all.reject { |item| item['active'] == false }.map do |element|
      [element[:id], element[:id]]
    end
  end

  def self.identifier(term)
    authority.all.reject { |item| item['active'] == false }.select { |department| department['label'] == term }.first['id']
  rescue StandardError
    nil
  end

  def self.label(id)
    authority.find(id).fetch('term')
  rescue StandardError
    Rails.logger.warn "DepartmentsService: cannot find '#{id}'"
    nil
  end

  def self.short_label(id)
    authority.find(id).fetch('short_label')
  end

  def self.include_current_value(value, _index, render_options, html_options)
    unless value.blank?
      html_options[:class] << ' force-select'
      # Add the current value to the options if it is not already present
      value_index = render_options.index { |opt| opt[0] == value }
      render_options += [[value, value]] if value_index == nil
    end
    [render_options, html_options]
  end
end
