# frozen_string_literal: true
module CdrRightsStatementsService
  mattr_accessor :authority
  self.authority = Qa::Authorities::Local.subauthority_for('rights_statements')

  # Allow all rights statements only for "General" works, or for admin users
  def self.select(work_type, admin_check)
    rights_type = if work_type.match?('generals')
                    ''
                  else
                    'general'
                  end

    authority.all
      .reject { |item| !admin_check && item['active'] == rights_type }
      .map { |element| [element[:label], element[:id]] }
  end

  def self.label(id)
    authority.find(id).fetch('term')
  rescue StandardError
    Rails.logger.warn "CdrRightsStatementsService: cannot find '#{id}'"
    puts "CdrRightsStatementsService: cannot find '#{id}'" # for migration log
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
