# frozen_string_literal: true
module CdrLicenseService
  mattr_accessor :authority
  self.authority = Qa::Authorities::Local.subauthority_for('licenses')

  def self.select(work_type, admin_check)
    is_data_set = work_type.match?('data_sets')
    filtered_elements = authority.all
      .reject { |item| is_data_set && item['active'] != 'data' } # hide non-data licenses from data sets
      .reject { |item| !admin_check && item['archived'] } # hide archived licenses from non-admins
    filtered_elements.map do |element|
      [element[:label], element[:id]]
    end
  end

  def self.label(id)
    authority.find(id).fetch('term')
  rescue StandardError
    Rails.logger.warn "CdrLicensesService: cannot find '#{id}'"
    puts "CdrLicensesService: cannot find '#{id}'" # for migration log
    id # cannot return nil
  end

  def self.include_current_value(value, _index, render_options, html_options)
    unless value.blank? || active?(value)
      html_options[:class] << ' force-select'
      render_options += [[label(value), value]]
    end
    [render_options, html_options]
  end

  def self.default_license(work_type)
    work_type == 'hyrax/data_sets' ? 'http://creativecommons.org/publicdomain/zero/1.0/' : ''
  end

end
