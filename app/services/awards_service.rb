module AwardsService
  mattr_accessor :authority
  self.authority = Qa::Authorities::Local.subauthority_for('awards')

  def self.select_all_options
    authority.all.map do |element|
      [element[:label], element[:id]]
    end
  end

  def self.select_active_options
    active_elements.map { |e| [e[:label], e[:id]] }
  end

  def self.active_elements
    authority.all.select { |e| e.fetch('active') }
  end

  def self.label(id)
    authority.find(id).fetch('term')
  rescue StandardError
    Rails.logger.warn "AwardsService: cannot find #{id}"
    puts "AwardsService: cannot find #{id}" # for migration log
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
