# frozen_string_literal: true
module LanguagesService
  mattr_accessor :authority
  self.authority = Qa::Authorities::Local.subauthority_for('languages')

  def self.select_all_options
    authority.all.map do |element|
      [element[:label], element[:id]]
    end
  end

  def self.label(id)
    return nil if id.blank?
    authority.find(Array.wrap(id).first).fetch('term')
  rescue StandardError
    Rails.logger.debug "LanguagesService: cannot find '#{id}'"
    puts "LanguagesService: cannot find '#{id}'" # for migration log
    nil
  end

  def self.iso639_1(id)
    return nil if id.blank?
    authority.find(id).fetch('iso639_1')
  rescue KeyError
    Rails.logger.warn "LanguageService: cannot find '#{id}'"
    nil
  end

  def self.include_current_value(value, _index, render_options, html_options)
    unless value.blank?
      html_options[:class] << ' force-select'
      render_options += [[label(value), value]]
    end
    [render_options, html_options]
  end
end
