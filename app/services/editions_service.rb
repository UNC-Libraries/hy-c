# frozen_string_literal: true
module EditionsService
  mattr_accessor :authority
  self.authority = Qa::Authorities::Local.subauthority_for('editions')

  def self.select_all_options
    authority.all.map do |element|
      [element[:label], element[:id]]
    end
  end

  def self.label(id)
    authority.find(id).fetch('term')
  end

  def self.include_current_value(value, _index, render_options, html_options)
    unless value.blank?
      html_options[:class] << ' force-select'
      render_options += [[label(value), value]]
    end
    [render_options, html_options]
  end
end
