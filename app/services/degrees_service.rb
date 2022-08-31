# frozen_string_literal: true
# app/services/degrees_service.rb
module DegreesService
  mattr_accessor :authority
  self.authority = Qa::Authorities::Local.subauthority_for('degrees')

  def self.select_all_options
    authority.all.map do |element|
      [element[:label], element[:id]]
    end
  end

  def self.select_active_options(term)
    active_elements(term).map { |e| [e[:label], e[:id]] }
  end

  def self.active_elements(term)
    if term == 'all'
      authority.all.select { |e| e.fetch('active') }
    else
      authority.all.select { |e| e.fetch('active') && e.fetch('work_type').include?(term) }
    end
  end

  def self.label(id)
    authority.find(id).fetch('term')
  rescue StandardError
    Rails.logger.warn "DegreesService: cannot find '#{id}'"
    puts "DegreesService: cannot find '#{id}'" # for migration log
    nil
  end

  def self.include_current_value(value, _index, render_options, html_options)
    unless value.blank? || active?(value)
      html_options[:class] << ' force-select'
      render_options += [[label(value), value]]
    end
    [render_options, html_options]
  end
end
