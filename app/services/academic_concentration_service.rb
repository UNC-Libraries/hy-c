# app/services/concentrations_service.rb
module ConcentrationsService
  mattr_accessor :authority
  self.authority = Qa::Authorities::Local.subauthority_for('concentrations')

  def self.select_all_options
    authority.all.reject{ |item| item['active'] == false }.map do |element|
      [element[:label], element[:id]]
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
