module CdrLicenseService
  mattr_accessor :authority
  self.authority = Qa::Authorities::Local.subauthority_for('licenses')

  def self.select(work_type)
    if work_type.match?('data_sets')
      license_type = 'all'
    else
      license_type = ''
    end

    authority.all.reject{ |item| item['active'] == license_type }.map do |element|
      [element[:label], element[:id]]
    end
  end

  def self.label(id)
    begin
      authority.find(id).fetch('term')
    rescue
      Rails.logger.warn "CdrLicensesService: cannot find '#{id}'"
      puts "CdrLicensesService: cannot find '#{id}'" # for migration log
      id # cannot return nil
    end
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
