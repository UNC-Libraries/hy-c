# app/services/concentrations_service.rb
module AcademicConcentrationService
  mattr_accessor :authority
  self.authority = Qa::Authorities::Local.subauthority_for('academic_concentration')

  def self.select(value)
    if value == 'all'
      authority.all.map do |element|
        [element[:label], element[:id]]
      end
    else
      regex = Regexp.new(value, Regexp::IGNORECASE)
      authority.all.reject{ |item| !(regex =~ item['work_type']) }.map do |element|
        [element[:label], element[:id]]
      end
    end
  end

  def self.label(id)
    authority.find(id).fetch('term')
  end

  def self.include_current_value(value, _index, render_options, html_options)
    unless value.blank? || active?(value)
      html_options[:class] << ' force-select'
      render_options += [[label(value), value]]
    end
    [render_options, html_options]
  end
end
