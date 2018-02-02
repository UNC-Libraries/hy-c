# app/services/departments_service.rb
module DepartmentsService
  mattr_accessor :authority
  self.authority = Qa::Authorities::Local.subauthority_for('departments')

  def self.select_all_options
    authority.all.reject{ |item| item['active'] == false }.map do |element|
      [element[:id], element[:label]]
    end
  end

  def self.identifier(term)
    begin
      authority.all.reject{ |item| item['active'] == false }.select { |department| department['label'] == term }.first['id']
    rescue
      nil
    end
  end

  def self.label(id)
    authority.find(id).fetch('term')
  end

  def self.include_current_value(value, _index, render_options, html_options)
    unless value.blank?
      html_options[:class] << ' force-select'
      render_options += [[identifier(value), value]]
    end
    [render_options, html_options]
  end
end
