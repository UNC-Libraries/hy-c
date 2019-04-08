module CdrRightsStatementsService
  mattr_accessor :authority
  self.authority = Qa::Authorities::Local.subauthority_for('rights_statements')

  # Allow all rights statements only for "General" works
  def self.select(work_type)
    if work_type.match?('generals')
      rights_type = ''
    else
      rights_type = 'general'
    end

    authority.all.reject{ |item| item['active'] == rights_type }.map do |element|
      [element[:label], element[:id]]
    end
  end

  def self.label(id)
    begin
      authority.find(id).fetch('term')
    rescue
      Rails.logger.warn "CdrRightsStatementsService: cannot find '#{id}'"
      puts "CdrRightsStatementsService: cannot find '#{id}'" # for migration log
      nil
    end
  end

  def self.include_current_value(value, _index, render_options, html_options)
    unless value.blank? || active?(value)
      html_options[:class] << ' force-select'
      render_options += [[label(value), value]]
    end
    [render_options, html_options]
  end
end