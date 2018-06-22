module CdrLicenseService
  mattr_accessor :authority
  self.authority = Qa::Authorities::Local.subauthority_for('licenses')

  def self.select(work_type)
    if work_type. == 'hyrax/data_sets'
      licenses = authority.search('data')
    else
      licenses = authority.all
    end

    licenses.map do |element|
      license = element[:label].split('?')[0] # Remove "data only attribute from label, if present"
      [license, element[:id]]
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

  def self.default_license(work_type)
    work_type == 'hyrax/data_sets' ? 'http://creativecommons.org/publicdomain/zero/1.0/' : ''
  end

end